part of 'live_matches_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  VERTICAL TIMELINE VIEW
//
//  Continuous time canvas: each 1-hour bucket is positioned at its real
//  clock Y (empty hours take space) so a card sticks to its time - not the
//  top of the list. Same-time streams share one horizontal line; overflow
//  scrolls sideways without moving time. Vertical scroll moves the clock;
//  Day / 12h / 6h set how many hours one screen height spans.
// ═════════════════════════════════════════════════════════════════════════════

mixin _LiveMatchesTimeline on ConsumerState<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  static const double _timelineRulerWidth = 112;
  static const double _timelinePlayheadFraction = 0.38;
  static const int _bucketMinutes = 60;

  /// Opaque card base so overlapping timeline rows don't bleed through.
  static const Color _timelineCardBase = Color(0xFF1C1C1C);

  /// Normalize an epoch (seconds or milliseconds) into a local [DateTime].
  static DateTime? _epochToDate(int value) {
    if (value <= 0) return null;
    // Seconds are ~1.7e9 today; milliseconds ~1.7e12. Split at 1e12.
    final ms = value >= 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Floor an epoch-ms to the start of its bucket window.
  static int _bucketFloorMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final total = dt.hour * 60 + dt.minute;
    final floored = total - (total % _bucketMinutes);
    return DateTime(dt.year, dt.month, dt.day, floored ~/ 60, floored % 60)
        .millisecondsSinceEpoch;
  }

  /// Misc / Other long events (Tour de France, etc.) stay airing for hours
  /// after kickoff - pin them to NOW so they ride the playhead instead of
  /// sitting in the past (users never scroll upward for history).
  bool _timelinePinAiringMiscToNow(_LiveMatchGridEntry e) {
    if (!_gridEntryIsLive(e)) return false;
    final cats = switch (e) {
      _LiveMatchGridEntryPpv(:final stream) => [stream.categoryName],
      _LiveMatchGridEntryStreamed(:final match) => [match.category],
      _LiveMatchGridEntryMerged(:final ppv, :final streamed) => [
        ppv.categoryName,
        streamed.category,
      ],
    };
    return cats.any((c) => normalizeLiveSportId(c) == 'other');
  }

  int _entryStartMs(_LiveMatchGridEntry e) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_timelinePinAiringMiscToNow(e)) return nowMs;
    final t = switch (e) {
      _LiveMatchGridEntryPpv(:final stream) =>
        stream.isAlwaysOn ? null : _epochToDate(stream.startsAt),
      _LiveMatchGridEntryStreamed(:final match) =>
        match.isAlwaysOn ? null : _epochToDate(match.dateMs),
      _LiveMatchGridEntryMerged(:final streamed) =>
        streamed.isAlwaysOn ? null : _epochToDate(streamed.dateMs),
    };
    return t?.millisecondsSinceEpoch ?? nowMs;
  }

  /// Entries for the current server + sport filter.
  List<_LiveMatchGridEntry> _timelineSourceEntries() {
    switch (_s._server) {
      case _LiveMatchesServer.all:
      case _LiveMatchesServer.iptvSports:
        return _s._allGridEntries;
      case _LiveMatchesServer.ppv:
        return _s._filteredDamiTv.map(_LiveMatchGridEntry.ppv).toList();
      case _LiveMatchesServer.streamed:
      case _LiveMatchesServer.mutStreams:
      case _LiveMatchesServer.forjaLive:
      case _LiveMatchesServer.stremio:
        return _s._displayStreamedMatches
            .map(_LiveMatchGridEntry.streamed)
            .toList();
    }
  }

  /// Live / airing / kickoff inside the current granularity window → timeline canvas.
  /// Everything else stays in [deferred] for lazy [SliverList] load below.
  ({List<_TimelineBucket> now, List<_LiveMatchGridEntry> deferred})
      _timelineSplitEntries() {
    final entries = _timelineSourceEntries();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final spanMs = _timelineSpanHours(_s._timelineGranularity) * 3600000;
    final windowStart = nowMs - spanMs ~/ 2;
    final windowEnd = nowMs + spanMs;

    final nowEntries = <_LiveMatchGridEntry>[];
    final deferred = <_LiveMatchGridEntry>[];
    for (final e in entries) {
      if (_gridEntryIsLive(e) || _timelinePinAiringMiscToNow(e)) {
        nowEntries.add(e);
        continue;
      }
      final ms = _entryStartMs(e);
      if (ms >= windowStart && ms <= windowEnd) {
        nowEntries.add(e);
      } else {
        deferred.add(e);
      }
    }

    deferred.sort(
      (a, b) => _entryStartMs(a).compareTo(_entryStartMs(b)),
    );

    final byBucket = <int, List<_LiveMatchGridEntry>>{};
    for (final e in nowEntries) {
      final bucket = _bucketFloorMs(_entryStartMs(e));
      (byBucket[bucket] ??= []).add(e);
    }
    final keys = byBucket.keys.toList()..sort();
    final buckets = [
      for (final k in keys)
        _TimelineBucket(bucketMs: k, entries: byBucket[k]!),
    ];
    return (now: buckets, deferred: deferred);
  }

  Widget _buildTimelineBody() {
    final split = _timelineSplitEntries();
    final buckets = split.now;
    final deferred = split.deferred;
    if (buckets.isEmpty && deferred.isEmpty) {
      _s._timelineTvRowIds.clear();
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_timeline_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No scheduled events',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final tvFocus = _s._tvFocus(context);
    if (tvFocus) {
      final nextIds = <String>{
        for (final b in buckets) 'tl-${b.bucketMs}',
      };
      _s._timelineTvRowIds
        ..clear()
        ..addAll(nextIds);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineGranularityBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportH = constraints.maxHeight;
              final cardWidth = _s._matchCardWidth(context);
              final cardHeight = _s._matchCardHeight(context);
              final gap = _s._gridGap(context);
              final spanHours = _timelineSpanHours(_s._timelineGranularity);
              final pxPerMs = buckets.isEmpty
                  ? viewportH / (spanHours * 3600000.0)
                  : viewportH / (spanHours * 3600000.0);
              final playheadY = viewportH * _timelinePlayheadFraction;

              final padTopMs = playheadY / pxPerMs;
              final padBottomMs =
                  (viewportH - playheadY + cardHeight) / pxPerMs;
              final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
              final contentStartMs = buckets.isEmpty
                  ? nowMs - padTopMs
                  : buckets.first.bucketMs - padTopMs;
              final contentEndMs = buckets.isEmpty
                  ? nowMs + padBottomMs
                  : buckets.last.bucketMs + padBottomMs;
              final canvasHeight =
                  ((contentEndMs - contentStartMs) * pxPerMs)
                      .clamp(cardHeight, viewportH * 4);

              _maybeAutoScrollToTime(
                contentStartMs: contentStartMs,
                pxPerMs: pxPerMs,
                playheadY: playheadY,
              );

              void scrollToNow() => _scrollTimelineToMs(
                    contentStartMs: contentStartMs,
                    pxPerMs: pxPerMs,
                    playheadY: playheadY,
                    focusMs: nowMs,
                    animate: true,
                  );

              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomScrollView(
                      controller: _s._timelineScrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: canvasHeight,
                            child: buckets.isEmpty
                                ? const SizedBox.shrink()
                                : AnimatedBuilder(
                                    animation: _s._timelineScrollController,
                                    builder: (context, _) {
                                      final scrollOffset =
                                          _s._timelineScrollController
                                                  .hasClients
                                              ? _s._timelineScrollController
                                                  .offset
                                              : 0.0;
                                      return _buildTimelineCanvas(
                                        buckets: buckets,
                                        contentStartMs: contentStartMs,
                                        pxPerMs: pxPerMs,
                                        cardWidth: cardWidth,
                                        cardHeight: cardHeight,
                                        gap: gap,
                                        hoverLift: ShellScope.inputPolicyOf(
                                          context,
                                        ).scaleOnHover,
                                        viewportHeight: viewportH,
                                        scrollOffset: scrollOffset,
                                      );
                                    },
                                  ),
                          ),
                        ),
                        if (deferred.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                _timelineRulerWidth + 12,
                                16,
                                ShellTokens.bodyHorizontalPadding,
                                8,
                              ),
                              child: Text(
                                'More events (${deferred.length})',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final entry = deferred[i];
                                final cardW = _s._matchCardWidth(context);
                                final cardH = _s._matchCardHeight(context);
                                return Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    _timelineRulerWidth + 12,
                                    0,
                                    ShellTokens.bodyHorizontalPadding,
                                    gap,
                                  ),
                                  child: SizedBox(
                                    width: cardW,
                                    height: cardH,
                                    child: _s._gridEntryCard(
                                      entry,
                                      i,
                                      1,
                                      null,
                                      tvRowId: 'tl-deferred',
                                      tvZone: ShellTvZone.row,
                                    ),
                                  ),
                                );
                              },
                              childCount: deferred.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _timelineRulerWidth,
                    child: _TimelineRuler(
                      width: _timelineRulerWidth,
                      controller: _s._timelineScrollController,
                      contentStartMs: contentStartMs,
                      pxPerMs: pxPerMs,
                      playheadFraction: _timelinePlayheadFraction,
                      granularity: _s._timelineGranularity,
                      onJumpToNow: scrollToNow,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _TimelineNowLine(
                        controller: _s._timelineScrollController,
                        contentStartMs: contentStartMs,
                        pxPerMs: pxPerMs,
                        leftInset: _timelineRulerWidth,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Positioned bucket rows on the continuous time canvas. Rows never scale or
  /// reorder - only the single hovered card is redrawn on top (desktop) via a
  /// transform-linked copy so it escapes overlapping neighbor rows.
  Widget _buildTimelineCanvas({
    required List<_TimelineBucket> buckets,
    required double contentStartMs,
    required double pxPerMs,
    required double cardWidth,
    required double cardHeight,
    required double gap,
    required bool hoverLift,
    required double viewportHeight,
    required double scrollOffset,
  }) {
    final children = <Widget>[];
    final cullTop = scrollOffset - viewportHeight * 0.75;
    final cullBottom = scrollOffset + viewportHeight * 1.75;

    for (var b = 0; b < buckets.length; b++) {
      final top = (buckets[b].bucketMs - contentStartMs) * pxPerMs;
      if (top + cardHeight < cullTop || top > cullBottom) continue;
      children.add(
        _buildTimedBucketRow(
          bucket: buckets[b],
          bucketIndex: b,
          top: top,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          gap: gap,
          hoverLift: hoverLift,
        ),
      );
    }

    // Elevated copy of just the hovered card, painted above every row. It
    // follows the real card's position and ignores pointers, so hover stays on
    // the original underneath (no flicker) - only this one card comes forward.
    final hb = _s._timelineHoveredBucketMs;
    final hi = _s._timelineHoveredIndex;
    if (hoverLift && hb != null && hi != null) {
      final bucketIndex = buckets.indexWhere((x) => x.bucketMs == hb);
      if (bucketIndex >= 0 && hi < buckets[bucketIndex].entries.length) {
        final bucket = buckets[bucketIndex];
        final link = _s._timelineCardLinks['$hb:$hi'];
        if (link != null) {
          children.add(
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                child: IgnorePointer(
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _timelineCardBase,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _s._gridEntryCard(
                        bucket.entries[hi],
                        hi,
                        bucket.entries.length,
                        null,
                        forceActive: true,
                        tvRowId: 'tl-${bucket.bucketMs}',
                        tvZone: ShellTvZone.row,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: children,
    );
  }

  Widget _buildTimedBucketRow({
    required _TimelineBucket bucket,
    required int bucketIndex,
    required double top,
    required double cardWidth,
    required double cardHeight,
    required double gap,
    required bool hoverLift,
  }) {
    final rowId = 'tl-${bucket.bucketMs}';
    final expanded = _s._timelineBucketExpanded[bucket.bucketMs] == true;
    final cap = _LiveMatchesScreenState._timelineBucketCardCap;
    final visibleCount = expanded
        ? bucket.entries.length
        : bucket.entries.length.clamp(0, cap);
    final hasMore = !expanded && bucket.entries.length > cap;
    final itemCount = visibleCount + (hasMore ? 1 : 0);

    final scroller = HorizontalScroller(
      height: cardHeight,
      padding: EdgeInsets.only(
        right: ShellTokens.bodyHorizontalPadding,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(width: gap),
      itemBuilder: (context, i) {
        if (hasMore && i == visibleCount) {
          return SizedBox(
            width: cardWidth * 0.55,
            height: cardHeight,
            child: shellFocusableTap(
              context: context,
              borderRadius: 14,
              onTap: () => setState(
                () => _s._timelineBucketExpanded[bucket.bucketMs] = true,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _timelineCardBase,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Text(
                    '+${bucket.entries.length - cap}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final entry = bucket.entries[i];
        // Opaque base so overlapping rows never show through the card.
        Widget slot = SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _timelineCardBase,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _s._gridEntryCard(
              entry,
              i,
              bucket.entries.length,
              null,
              tvRowId: rowId,
              tvZone: ShellTvZone.row,
              onHoverChanged: hoverLift
                  ? (hovered) =>
                      _onTimelineCardHover(bucket.bucketMs, i, hovered)
                  : null,
            ),
          ),
        );
        if (hoverLift) {
          final link = _s._timelineCardLinks.putIfAbsent(
            '${bucket.bucketMs}:$i',
            () => LayerLink(),
          );
          slot = CompositedTransformTarget(link: link, child: slot);
        }
        return slot;
      },
    );

    return Positioned(
      key: ValueKey(bucket.bucketMs),
      left: _timelineRulerWidth + 6,
      right: 0,
      top: top,
      height: cardHeight,
      child: TvCatalogRow(
        tabId: _LiveMatchesScreenState._tabId,
        rowId: rowId,
        sortOrder: 2 + bucketIndex,
        itemCount: bucket.entries.length,
        child: scroller,
      ),
    );
  }

  /// Track the single hovered card so its elevated copy can be drawn on top.
  /// Only clears when the card leaving is still the tracked one, so moving
  /// between cards never drops the newly entered card.
  void _onTimelineCardHover(int bucketMs, int index, bool hovered) {
    if (hovered) {
      if (_s._timelineHoveredBucketMs != bucketMs ||
          _s._timelineHoveredIndex != index) {
        setState(() {
          _s._timelineHoveredBucketMs = bucketMs;
          _s._timelineHoveredIndex = index;
        });
      }
    } else if (_s._timelineHoveredBucketMs == bucketMs &&
        _s._timelineHoveredIndex == index) {
      setState(() {
        _s._timelineHoveredBucketMs = null;
        _s._timelineHoveredIndex = null;
      });
    }
  }

  /// Returns true once the scroll view has clients and the offset was applied.
  bool _scrollTimelineToMs({
    required double contentStartMs,
    required double pxPerMs,
    required double playheadY,
    required double focusMs,
    bool animate = false,
  }) {
    final ctrl = _s._timelineScrollController;
    if (!ctrl.hasClients) return false;
    final target = (focusMs - contentStartMs) * pxPerMs - playheadY;
    final clamped = target.clamp(0.0, ctrl.position.maxScrollExtent);
    if (animate) {
      ctrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      ctrl.jumpTo(clamped);
    }
    return true;
  }

  /// On first open of the timeline (or after a view/granularity reset), land
  /// the playhead on *now* - not the first card. Retries until the scroll
  /// view is attached; only then marks the one-shot as done.
  void _maybeAutoScrollToTime({
    required double contentStartMs,
    required double pxPerMs,
    required double playheadY,
  }) {
    if (_s._timelineAutoScrolled) return;

    void attempt() {
      if (!mounted || _s._timelineAutoScrolled) return;
      final ok = _scrollTimelineToMs(
        contentStartMs: contentStartMs,
        pxPerMs: pxPerMs,
        playheadY: playheadY,
        focusMs: DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
      if (ok) {
        _s._timelineAutoScrolled = true;
        return;
      }
      // Scroll view not attached yet - try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  Widget _buildTimelineGranularityBar() {
    final values = _TimelineGranularity.values;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        2,
        ShellTokens.bodyHorizontalPadding,
        6,
      ),
      child: FocusTraversalGroup(
        child: Align(
          alignment: Alignment.centerLeft,
          // Segmented control: 4 small equal-width tabs in one rounded shell.
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ForjaShellColors.cinematic.borderSubtle,
              ),
            ),
            child: Builder(
              builder: (context) {
                final row = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < values.length; i++)
                      _buildTimelineGranularityTab(values[i], i, values.length),
                  ],
                );
                if (!_s._tvFocus(context)) return row;
                return TvChipStrip(
                  tabId: _LiveMatchesScreenState._tabId,
                  rowId: _LiveMatchesScreenState._granularityRowId,
                  sortOrder: 1,
                  itemCount: values.length,
                  resultsRowId: _s._timelineTvRowIds.isNotEmpty
                      ? _s._timelineTvRowIds.first
                      : _LiveMatchesScreenState._gridRowId,
                  builder: (context, edgesFor) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < values.length; i++)
                        _buildTimelineGranularityTab(
                          values[i],
                          i,
                          values.length,
                          edges: edgesFor(i),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineGranularityTab(
    _TimelineGranularity g,
    int index,
    int itemCount, {
    TvChipEdges? edges,
  }) {
    final selected = _s._timelineGranularity == g;
    final cinematic = ForjaShellColors.cinematic;
    final fg = selected ? cinematic.textPrimary : cinematic.textSecondary;
    const radius = 9.0;

    final tab = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? ForjaShellColors.chipSelectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? ForjaShellColors.chipSelectedBorder
              : Colors.transparent,
        ),
      ),
      child: Text(
        _timelineGranularityLabel(g),
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      listIndex: index,
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._granularityRowId,
      tvItemIndex: index,
      onLeftEdge: edges?.onLeft,
      onRightEdge: edges?.onRight,
      onUpEdge: () => _s._focusTopBarItem(_s._topBarCatalogIndex),
      onDownEdge: () => _s._restoreLiveMatchesTvFocus(),
      onTap: () {
        _s._timelineAutoScrolled = false;
        _s._resetTimelineLazyState();
        setState(() => _s._timelineGranularity = g);
      },
      child: tab,
    );
  }
}

class _TimelineBucket {
  const _TimelineBucket({required this.bucketMs, required this.entries});

  /// Start of the 1-hour window (epoch ms).
  final int bucketMs;
  final List<_LiveMatchGridEntry> entries;
}

// ─── Animated ruler gauge ─────────────────────────────────────────────────────

/// Distance from the ruler's right edge to its vertical time axis. Shared by
/// the ruler painter and the NOW badge so the badge stays centered on the line.
const double _rulerLineInset = 12;

({int minorMin, int majorMin}) _timelineTickIntervals(int spanHours) =>
    switch (spanHours) {
      3 => (minorMin: 15, majorMin: 30),
      6 => (minorMin: 15, majorMin: 60),
      12 => (minorMin: 30, majorMin: 120),
      _ => (minorMin: 60, majorMin: 180),
    };

class _TimelineRuler extends StatelessWidget {
  const _TimelineRuler({
    required this.width,
    required this.controller,
    required this.contentStartMs,
    required this.pxPerMs,
    required this.playheadFraction,
    required this.granularity,
    required this.onJumpToNow,
  });

  final double width;
  final ScrollController controller;
  final double contentStartMs;
  final double pxPerMs;
  final double playheadFraction;
  final _TimelineGranularity granularity;
  final VoidCallback onJumpToNow;

  double _centerMs(double viewportHeight) {
    final offset = controller.hasClients ? controller.offset : 0.0;
    final playheadY = viewportHeight * playheadFraction;
    return contentStartMs + (offset + playheadY) / pxPerMs;
  }

  @override
  Widget build(BuildContext context) {
    final spanHours = _timelineSpanHours(granularity);
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final centerMs = _centerMs(height);
              final centerDt = DateTime.fromMillisecondsSinceEpoch(
                centerMs.round(),
              );
              final playheadY = height * playheadFraction;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ticks / line ignore hits so vertical scroll still works
                  // over the ruler gutter.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TimelineRulerPainter(
                          centerMs: centerMs,
                          spanHours: spanHours,
                          playheadFraction: playheadFraction,
                          accent: ForjaShellColors.sectionAccent,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: playheadY - 22,
                    child: _TimelinePlayheadPill(
                      time: centerDt,
                      onTap: onJumpToNow,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Horizontal green line at the real current time. Positioned over the whole
/// timeline, it tracks scrolling (via [controller]) and re-renders each minute
/// so it drifts down as time passes.
class _TimelineNowLine extends StatefulWidget {
  const _TimelineNowLine({
    required this.controller,
    required this.contentStartMs,
    required this.pxPerMs,
    required this.leftInset,
  });

  final ScrollController controller;
  final double contentStartMs;
  final double pxPerMs;
  final double leftInset;

  @override
  State<_TimelineNowLine> createState() => _TimelineNowLineState();
}

class _TimelineNowLineState extends State<_TimelineNowLine> {
  static const _green = Color(0xFF37E36B);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final offset =
                widget.controller.hasClients ? widget.controller.offset : 0.0;
            final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
            final y = (nowMs - widget.contentStartMs) * widget.pxPerMs - offset;
            if (y < 0 || y > height) return const SizedBox.shrink();
            // Green line runs across the content; the NOW badge is anchored on
            // the ruler axis (like the tick labels) and both sit on the topmost
            // layer so nothing covers them.
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: widget.leftInset,
                  right: 0,
                  top: y - 1,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _green,
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  // Center the badge on the ruler axis (the vertical timeline
                  // line sits at leftInset - 12; see _TimelineRulerPainter).
                  left: 0,
                  width: (widget.leftInset - _rulerLineInset) * 2,
                  top: y - 9,
                  height: 18,
                  child: const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'NOW',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  _TimelineRulerPainter({
    required this.centerMs,
    required this.spanHours,
    required this.playheadFraction,
    required this.accent,
  });

  final double centerMs;
  final int spanHours;
  final double playheadFraction;
  final Color accent;

  static const _monthAbbr = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  DateTime _alignFloor(DateTime d, int stepMin) {
    final m = d.hour * 60 + d.minute;
    final fl = m - (m % stepMin);
    return DateTime(d.year, d.month, d.day, fl ~/ 60, fl % 60);
  }

  void _text(
    Canvas canvas,
    String value,
    Offset rightBaseline, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rightBaseline.dx - tp.width, rightBaseline.dy - tp.height / 2),
    );
  }

  /// Stable per-day tint so each day's ruler segment reads differently.
  static Color _dayColor(DateTime dayStart) {
    final key = dayStart.difference(DateTime(2000)).inDays;
    final hue = (key * 47) % 360;
    return HSVColor.fromAHSV(0.75, hue.toDouble(), 0.55, 0.95).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lineX = size.width - _rulerLineInset;
    final playheadY = size.height * playheadFraction;
    final pxPerMs = size.height / (spanHours * 3600000);

    // Faint base rail.
    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.5,
    );

    // Per-day coloured segments over the rail; today stays white.
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final topMs = centerMs + (0 - playheadY) / pxPerMs;
    final bottomMs = centerMs + (size.height - playheadY) / pxPerMs;
    final topDt = DateTime.fromMillisecondsSinceEpoch(topMs.round());
    var dayStart = DateTime(topDt.year, topDt.month, topDt.day);
    while (dayStart.millisecondsSinceEpoch < bottomMs) {
      final dayEnd = dayStart.add(const Duration(days: 1));
      final yStart =
          playheadY + (dayStart.millisecondsSinceEpoch - centerMs) * pxPerMs;
      final yEnd =
          playheadY + (dayEnd.millisecondsSinceEpoch - centerMs) * pxPerMs;
      final segTop = yStart.clamp(0.0, size.height);
      final segBottom = yEnd.clamp(0.0, size.height);
      if (segBottom > segTop) {
        final isToday = dayStart == todayStart;
        canvas.drawLine(
          Offset(lineX, segTop),
          Offset(lineX, segBottom),
          Paint()
            ..color = isToday
                ? Colors.white.withValues(alpha: 0.9)
                : _dayColor(dayStart)
            ..strokeWidth = 3,
        );
      }
      dayStart = dayEnd;
    }

    canvas.drawCircle(
      Offset(lineX, playheadY),
      12,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawLine(
      Offset(0, playheadY),
      Offset(lineX, playheadY),
      Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(lineX, playheadY), 3.5, Paint()..color = accent);

    final intervals = _timelineTickIntervals(spanHours);
    final centerDt = DateTime.fromMillisecondsSinceEpoch(centerMs.round());
    final padHours = spanHours ~/ 2 + 1;
    var t = _alignFloor(
      centerDt.subtract(Duration(hours: padHours)),
      intervals.minorMin,
    );
    final endDt = centerDt.add(Duration(hours: padHours));

    while (!t.isAfter(endDt)) {
      final y = playheadY + (t.millisecondsSinceEpoch - centerMs) * pxPerMs;
      if (y >= -4 && y <= size.height + 4) {
        final minuteOfDay = t.hour * 60 + t.minute;
        final isMajor = minuteOfDay % intervals.majorMin == 0;
        final near = (y - playheadY).abs() < 16;
        final len = isMajor ? 14.0 : 7.0;

        canvas.drawLine(
          Offset(lineX - len, y),
          Offset(lineX, y),
          Paint()
            ..color = near
                ? accent.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: isMajor ? 0.5 : 0.22)
            ..strokeWidth = isMajor ? 2 : 1,
        );

        if (isMajor && !near) {
          final label =
              '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}';
          final isMidnight = t.hour == 0 && t.minute == 0;
          _text(
            canvas,
            label,
            Offset(lineX - len - 8, isMidnight ? y - 6 : y),
            size: 12,
            color: Colors.white.withValues(alpha: 0.6),
          );
          if (isMidnight) {
            _text(
              canvas,
              '${t.day} ${_monthAbbr[t.month - 1]}',
              Offset(lineX - len - 8, y + 8),
              size: 10,
              color: accent.withValues(alpha: 0.85),
              weight: FontWeight.w700,
            );
          }
        }
      }
      t = t.add(Duration(minutes: intervals.minorMin));
    }
  }

  @override
  bool shouldRepaint(_TimelineRulerPainter old) =>
      old.centerMs != centerMs ||
      old.spanHours != spanHours ||
      old.playheadFraction != playheadFraction;
}

class _TimelinePlayheadPill extends StatelessWidget {
  const _TimelinePlayheadPill({required this.time, required this.onTap});

  final DateTime time;
  final VoidCallback onTap;

  static const _weekday = [
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN', //
  ];
  static const _month = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final accent = ForjaShellColors.sectionAccent;
    final date =
        '${_weekday[time.weekday - 1]} ${time.day} ${_month[time.month - 1]}';
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            clock,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: 'Jump to now',
      waitDuration: const Duration(milliseconds: 600),
      child: shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: 10,
        scaleOnFocus: 1.0,
        showFocusBorder: true,
        tvTabId: _LiveMatchesScreenState._tabId,
        tvZone: ShellTvZone.topBar,
        child: pill,
      ),
    );
  }
}
