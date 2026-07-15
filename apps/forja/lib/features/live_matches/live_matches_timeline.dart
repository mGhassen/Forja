part of 'live_matches_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  VERTICAL TIMELINE VIEW
//
//  Events are grouped into 30-minute buckets. Each bucket is one horizontal
//  row of the same backdrop cards — same-time streams share a line; overflow
//  scrolls sideways without moving the time. Vertical scroll moves through
//  time buckets while an animated ruler gauge on the left tracks the playhead.
//  Day / 12h / 6h buttons set how many hours one screen height of the ruler
//  spans (the timeline scale).
// ═════════════════════════════════════════════════════════════════════════════

mixin _LiveMatchesTimeline on State<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  static const double _timelineRulerWidth = 112;
  static const double _timelinePlayheadFraction = 0.38;
  static const double _timelineTopPad = 4;
  static const int _bucketMinutes = 30;

  /// Normalize an epoch (seconds or milliseconds) into a local [DateTime].
  static DateTime? _epochToDate(int value) {
    if (value <= 0) return null;
    // Seconds are ~1.7e9 today; milliseconds ~1.7e12. Split at 1e12.
    final ms = value >= 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Floor an epoch-ms to the start of its 30-minute bucket.
  static int _bucketFloorMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final minute = dt.minute < _bucketMinutes ? 0 : _bucketMinutes;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, minute)
        .millisecondsSinceEpoch;
  }

  int _entryStartMs(_LiveMatchGridEntry e) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final t = switch (e) {
      _LiveMatchGridEntryPpv(:final stream) =>
        stream.isAlwaysOn ? null : _epochToDate(stream.startsAt),
      _LiveMatchGridEntryStreamed(:final match) =>
        match.isAlwaysOn ? null : _epochToDate(match.dateMs),
      _LiveMatchGridEntryCdnSport(:final event) =>
        _epochToDate(_cdnSportStartKey(event)),
    };
    return t?.millisecondsSinceEpoch ?? nowMs;
  }

  /// Chronological 30-minute buckets. Same-time streams share one row.
  List<_TimelineBucket> get _timelineBuckets {
    final entries = <_LiveMatchGridEntry>[];
    switch (_s._server) {
      case _LiveMatchesServer.all:
        entries.addAll(_s._filteredDamiTv.map(_LiveMatchGridEntry.ppv));
        entries.addAll(_s._filteredStreamed.map(_LiveMatchGridEntry.streamed));
        entries.addAll(_s._filteredCdnSports.map(_LiveMatchGridEntry.cdnSport));
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
              final cardWidth = _s._matchCardWidth(context);
              final cardHeight = _s._matchCardHeight(context);
              final gap = _s._gridGap(context);
              final rowExtent = cardHeight + gap;
              final rowMs = [for (final b in buckets) b.bucketMs];

              _maybeAutoScrollBuckets(buckets, rowExtent);

              // Full-width vertical list of 30-min rows; ruler overlaid on the
              // left with IgnorePointer so scroll over the timeline space
              // still drives the shared vertical controller. Cards in a row
              // scroll horizontally — time for that row stays put.
              return Stack(
                children: [
                  Positioned.fill(
                    child: ListView.builder(
                      controller: _s._timelineScrollController,
                      padding: EdgeInsets.fromLTRB(
                        _timelineRulerWidth + 6,
                        _timelineTopPad,
                        0,
                        20,
                      ),
                      itemExtent: rowExtent,
                      itemCount: buckets.length,
                      itemBuilder: (context, rowIndex) {
                        final bucket = buckets[rowIndex];
                        final flatBase = buckets
                            .take(rowIndex)
                            .fold<int>(0, (n, b) => n + b.entries.length);
                        return Align(
                          alignment: Alignment.topLeft,
                          child: HorizontalScroller(
                            height: cardHeight,
                            padding: EdgeInsets.only(
                              right: ShellTokens.bodyHorizontalPadding,
                            ),
                            itemCount: bucket.entries.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(width: gap),
                            itemBuilder: (context, i) {
                              final flatIndex = flatBase + i;
                              return SizedBox(
                                width: cardWidth,
                                child: _s._gridEntryCard(
                                  bucket.entries[i],
                                  flatIndex,
                                  bucket.entries.length,
                                  rowIndex == 0
                                      ? () => _s._focusTopBarItem(
                                          _LiveMatchesScreenState
                                              ._topBarServersIndex,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _timelineRulerWidth,
                    child: IgnorePointer(
                      child: _TimelineRuler(
                        width: _timelineRulerWidth,
                        controller: _s._timelineScrollController,
                        rowMs: rowMs,
                        rowExtent: rowExtent,
                        topPad: _timelineTopPad,
                        playheadFraction: _timelinePlayheadFraction,
                        granularity: _s._timelineGranularity,
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

  void _maybeAutoScrollBuckets(
    List<_TimelineBucket> buckets,
    double rowExtent,
  ) {
    if (_s._timelineAutoScrolled) return;
    _s._timelineAutoScrolled = true;

    final nowBucket = _bucketFloorMs(DateTime.now().millisecondsSinceEpoch);
    var targetRow = 0;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].bucketMs >= nowBucket) {
        targetRow = i;
        break;
      }
      targetRow = i;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = _s._timelineScrollController;
      if (!mounted || !ctrl.hasClients) return;
      final target = targetRow * rowExtent;
      ctrl.jumpTo(target.clamp(0.0, ctrl.position.maxScrollExtent));
    });
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
                onTap: () => setState(() => _s._timelineGranularity = g),
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

  /// Start of the 30-minute window (epoch ms).
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
    required this.rowMs,
    required this.rowExtent,
    required this.topPad,
    required this.playheadFraction,
    required this.granularity,
  });

  final double width;
  final ScrollController controller;
  final List<int> rowMs;
  final double rowExtent;
  final double topPad;
  final double playheadFraction;
  final _TimelineGranularity granularity;

  double _centerMs(double viewportHeight) {
    if (rowMs.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toDouble();
    }
    final offset = controller.hasClients ? controller.offset : 0.0;
    final playheadY = viewportHeight * playheadFraction;
    var pos = (offset + playheadY - topPad) / rowExtent;
    pos = pos.clamp(0.0, (rowMs.length - 1).toDouble());
    final i0 = pos.floor();
    final i1 = (i0 + 1).clamp(0, rowMs.length - 1);
    final f = pos - i0;
    return rowMs[i0] + (rowMs[i1] - rowMs[i0]) * f;
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
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TimelineRulerPainter(
                        centerMs: centerMs,
                        spanHours: spanHours,
                        playheadFraction: playheadFraction,
                        accent: ForjaShellColors.sectionAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: playheadY - 22,
                    child: _TimelinePlayheadPill(time: centerDt),
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

  @override
  void paint(Canvas canvas, Size size) {
    final lineX = size.width - 12;
    final playheadY = size.height * playheadFraction;
    final pxPerMs = size.height / (spanHours * 3600000);

    // Rail line.
    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.5,
    );

    // Glow + playhead accent line.
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
  const _TimelinePlayheadPill({required this.time});

  final DateTime time;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // Opaque so the playhead line sits behind the time card, not through it.
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
  }
}
