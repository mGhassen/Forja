part of 'live_matches_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  VERTICAL TIMELINE VIEW
//
//  Continuous time canvas: each 1-hour bucket is positioned at its real
//  clock Y (empty hours take space) so a card sticks to its time — not the
//  top of the list. Same-time streams share one horizontal line; overflow
//  scrolls sideways without moving time. Vertical scroll moves the clock;
//  Day / 12h / 6h set how many hours one screen height spans.
// ═════════════════════════════════════════════════════════════════════════════

mixin _LiveMatchesTimeline on State<LiveMatchesScreen> {
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

  int _entryStartMs(_LiveMatchGridEntry e) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final t = switch (e) {
      _LiveMatchGridEntryPpv(:final stream) =>
        stream.isAlwaysOn ? null : _epochToDate(stream.startsAt),
      _LiveMatchGridEntryStreamed(:final match) =>
        match.isAlwaysOn ? null : _epochToDate(match.dateMs),
      _LiveMatchGridEntryMerged(:final streamed) =>
        streamed.isAlwaysOn ? null : _epochToDate(streamed.dateMs),
      _LiveMatchGridEntryCdnSport(:final event) =>
        _epochToDate(_cdnSportStartKey(event)),
    };
    return t?.millisecondsSinceEpoch ?? nowMs;
  }

  /// Chronological 1-hour buckets. Same-hour streams share one row.
  List<_TimelineBucket> get _timelineBuckets {
    final entries = <_LiveMatchGridEntry>[];
    switch (_s._server) {
      case _LiveMatchesServer.all:
        entries.addAll(_s._allGridEntries);
      case _LiveMatchesServer.ppv:
        entries.addAll(_s._filteredDamiTv.map(_LiveMatchGridEntry.ppv));
      case _LiveMatchesServer.streamed:
        entries.addAll(_s._filteredStreamed.map(_LiveMatchGridEntry.streamed));
      case _LiveMatchesServer.cdnLive:
        entries.addAll(_s._filteredCdnSports.map(_LiveMatchGridEntry.cdnSport));
    }

    final byBucket = <int, List<_LiveMatchGridEntry>>{};
    for (final e in entries) {
      final bucket = _bucketFloorMs(_entryStartMs(e));
      (byBucket[bucket] ??= []).add(e);
    }

    final keys = byBucket.keys.toList()..sort();
    return [
      for (final k in keys)
        _TimelineBucket(bucketMs: k, entries: byBucket[k]!),
    ];
  }

  Widget _buildTimelineBody() {
    final buckets = _timelineBuckets;
    if (buckets.isEmpty) {
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

    final totalCards = buckets.fold<int>(0, (n, b) => n + b.entries.length);
    final tvFocus = _s._tvFocus(context);
    if (tvFocus) {
      _s._registerGridRow(totalCards);
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
              final pxPerMs = viewportH / (spanHours * 3600000.0);
              final playheadY = viewportH * _timelinePlayheadFraction;

              // Pad so the first/last bucket can sit on the playhead.
              final padTopMs = playheadY / pxPerMs;
              final padBottomMs =
                  (viewportH - playheadY + cardHeight) / pxPerMs;
              final contentStartMs = buckets.first.bucketMs - padTopMs;
              final contentEndMs = buckets.last.bucketMs + padBottomMs;
              final contentHeight =
                  (contentEndMs - contentStartMs) * pxPerMs;

              _maybeAutoScrollToTime(
                contentStartMs: contentStartMs,
                pxPerMs: pxPerMs,
                playheadY: playheadY,
              );

              void scrollToNow() => _scrollTimelineToMs(
                    contentStartMs: contentStartMs,
                    pxPerMs: pxPerMs,
                    playheadY: playheadY,
                    focusMs:
                        DateTime.now().millisecondsSinceEpoch.toDouble(),
                    animate: true,
                  );

              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      controller: _s._timelineScrollController,
                      child: SizedBox(
                        height: contentHeight,
                        child: _buildTimelineCanvas(
                          buckets: buckets,
                          contentStartMs: contentStartMs,
                          pxPerMs: pxPerMs,
                          cardWidth: cardWidth,
                          cardHeight: cardHeight,
                          gap: gap,
                        ),
                      ),
                    ),
                  ),
                  // Ruler paint ignores pointers (scroll passes through); only
                  // the playhead pill is tappable — jumps the clock to now.
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
                  // Green marker at the real current time, tracked across
                  // scroll and ticking every minute.
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

  /// Positioned bucket rows on the continuous time canvas. Cards keep their
  /// own in-place hover (play overlay), so rows never scale here — only paint
  /// order changes so the hovered row sits above overlapping neighbors.
  Widget _buildTimelineCanvas({
    required List<_TimelineBucket> buckets,
    required double contentStartMs,
    required double pxPerMs,
    required double cardWidth,
    required double cardHeight,
    required double gap,
  }) {
    // Paint hovered bucket last so it sits above overlapping hour rows.
    final hoveredMs = _s._timelineHoveredBucketMs;
    final rows = <Widget>[];
    Widget? hoveredRow;
    for (var b = 0; b < buckets.length; b++) {
      final bucket = buckets[b];
      final row = _buildTimedBucketRow(
        bucket: bucket,
        bucketIndex: b,
        buckets: buckets,
        top: (bucket.bucketMs - contentStartMs) * pxPerMs,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        gap: gap,
      );
      if (hoveredMs != null && bucket.bucketMs == hoveredMs) {
        hoveredRow = row;
      } else {
        rows.add(row);
      }
    }
    if (hoveredRow != null) rows.add(hoveredRow);

    return Stack(
      clipBehavior: Clip.none,
      children: rows,
    );
  }

  Widget _buildTimedBucketRow({
    required _TimelineBucket bucket,
    required int bucketIndex,
    required List<_TimelineBucket> buckets,
    required double top,
    required double cardWidth,
    required double cardHeight,
    required double gap,
  }) {
    final flatBase = buckets
        .take(bucketIndex)
        .fold<int>(0, (n, b) => n + b.entries.length);

    return Positioned(
      key: ValueKey(bucket.bucketMs),
      left: _timelineRulerWidth + 6,
      right: 0,
      top: top,
      height: cardHeight,
      // One region per hour row — moving between cards in the same bucket
      // must not clear the elevated paint order.
      child: MouseRegion(
        onEnter: (_) {
          if (_s._timelineHoveredBucketMs != bucket.bucketMs) {
            setState(() => _s._timelineHoveredBucketMs = bucket.bucketMs);
          }
        },
        onExit: (_) {
          if (_s._timelineHoveredBucketMs == bucket.bucketMs) {
            setState(() => _s._timelineHoveredBucketMs = null);
          }
        },
        child: HorizontalScroller(
          height: cardHeight,
          padding: EdgeInsets.only(
            right: ShellTokens.bodyHorizontalPadding,
          ),
          // Horizontal scroll only — does not move the vertical time canvas.
          itemCount: bucket.entries.length,
          separatorBuilder: (_, _) => SizedBox(width: gap),
          itemBuilder: (context, i) {
            final flatIndex = flatBase + i;
            final entry = bucket.entries[i];
            final upEdge = bucketIndex == 0
                ? () => _s._focusTopBarItem(
                    _LiveMatchesScreenState._topBarServersIndex,
                  )
                : null;
            // Opaque base so overlapping rows never show through the card.
            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _timelineCardBase,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _s._gridEntryCard(
                  entry,
                  flatIndex,
                  bucket.entries.length,
                  upEdge,
                ),
              ),
            );
          },
        ),
      ),
    );
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
  /// the playhead on *now* — not the first card. Retries until the scroll
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
      // Scroll view not attached yet — try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  Widget _buildTimelineGranularityBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        2,
        ShellTokens.bodyHorizontalPadding,
        6,
      ),
      child: FocusTraversalGroup(
        child: Row(
          children: [
            for (final g in _TimelineGranularity.values) ...[
              if (g != _TimelineGranularity.values.first)
                const SizedBox(width: 6),
              ForjaShellChip(
                label: _timelineGranularityLabel(g),
                selected: _s._timelineGranularity == g,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                fontSize: 11.5,
                onTap: () {
                  _s._timelineAutoScrolled = false;
                  setState(() => _s._timelineGranularity = g);
                },
              ),
            ],
          ],
        ),
      ),
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

({int minorMin, int majorMin}) _timelineTickIntervals(int spanHours) =>
    switch (spanHours) {
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
                  right: 10,
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
                  left: 0,
                  width: widget.leftInset,
                  top: y - 9,
                  height: 18,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
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
    final lineX = size.width - 12;
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'Jump to now',
          waitDuration: const Duration(milliseconds: 600),
          child: Container(
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
          ),
        ),
      ),
    );
  }
}
