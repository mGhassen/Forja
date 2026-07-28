import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/iptv/widgets/iptv_live_favorite_button.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Pure layout maths for the Live catalog EPG timeline.
class IptvEpgTimeline {
  IptvEpgTimeline({
    required this.start,
    required this.end,
    this.pointsPerMinute = 3.5,
  });

  final DateTime start;
  final DateTime end;
  final double pointsPerMinute;

  double get totalMinutes => end.difference(start).inSeconds / 60.0;
  double get totalWidth => totalMinutes * pointsPerMinute;

  double xFor(DateTime date) {
    final clamped = date.isBefore(start)
        ? start
        : (date.isAfter(end) ? end : date);
    return clamped.difference(start).inSeconds / 60.0 * pointsPerMinute;
  }

  double widthBetween(DateTime a, DateTime b) =>
      (xFor(b) - xFor(a)).clamp(0.0, double.infinity);

  List<DateTime> get halfHourTicks {
    final out = <DateTime>[];
    var cursor = start;
    const step = Duration(minutes: 30);
    while (!cursor.isAfter(end)) {
      out.add(cursor);
      cursor = cursor.add(step);
    }
    return out;
  }

  static IptvEpgTimeline live({DateTime? now}) {
    final window = IptvController.guideWindow(now: now);
    return IptvEpgTimeline(start: window.start, end: window.end);
  }
}

class _EpgCell {
  const _EpgCell({
    required this.entry,
    required this.left,
    required this.width,
    required this.isGap,
  });

  final EpgEntry? entry;
  final double left;
  final double width;
  final bool isGap;
}

/// Sticky channel rail + row metrics (shared with [_ChannelCell]).
const _kEpgChannelColW = 280.0;
const _kEpgRowH = 68.0;
const _kEpgHeaderH = 36.0;

/// Desktop Live catalog EPG: sticky channels + sticky ruler + duration blocks.
class IptvEpgGuideView extends StatefulWidget {
  const IptvEpgGuideView({
    super.key,
    required this.ctrl,
    required this.streams,
    required this.onPlay,
  });

  final IptvController ctrl;
  final List<IptvStream> streams;
  final ValueChanged<IptvStream> onPlay;

  @override
  State<IptvEpgGuideView> createState() => _IptvEpgGuideViewState();
}

class _IptvEpgGuideViewState extends State<IptvEpgGuideView> {
  static const _channelColW = _kEpgChannelColW;
  static const _rowH = _kEpgRowH;
  static const _headerH = _kEpgHeaderH;

  late IptvEpgTimeline _timeline;
  final _hRuler = ScrollController();
  final _hGrid = ScrollController();
  final _vChannels = ScrollController();
  final _vGrid = ScrollController();
  bool _syncingH = false;
  bool _syncingV = false;
  bool _didInitialScroll = false;
  Timer? _nowTick;
  DateTime _now = DateTime.now();
  /// Visible time slice (+ buffer) - programmes outside are not tiled.
  late DateTime _sliceStart;
  late DateTime _sliceEnd;

  @override
  void initState() {
    super.initState();
    _timeline = IptvEpgTimeline.live(now: _now);
    _sliceStart = _now.subtract(const Duration(hours: 1));
    _sliceEnd = _now.add(const Duration(hours: 3));
    _hRuler.addListener(_onHRuler);
    _hGrid.addListener(_onHGrid);
    _vChannels.addListener(_onVChannels);
    _vGrid.addListener(_onVGrid);
    _nowTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _nowTick?.cancel();
    _hRuler.removeListener(_onHRuler);
    _hGrid.removeListener(_onHGrid);
    _vChannels.removeListener(_onVChannels);
    _vGrid.removeListener(_onVGrid);
    _hRuler.dispose();
    _hGrid.dispose();
    _vChannels.dispose();
    _vGrid.dispose();
    super.dispose();
  }

  void _onHRuler() {
    if (_syncingH || !_hGrid.hasClients) return;
    _syncingH = true;
    _hGrid.jumpTo(_hRuler.offset.clamp(0.0, _hGrid.position.maxScrollExtent));
    _syncingH = false;
    _syncVisibleSlice();
  }

  void _onHGrid() {
    if (_syncingH || !_hRuler.hasClients) return;
    _syncingH = true;
    _hRuler.jumpTo(_hGrid.offset.clamp(0.0, _hRuler.position.maxScrollExtent));
    _syncingH = false;
    _syncVisibleSlice();
  }

  DateTime _dateAtX(double x) {
    final minutes = (x / _timeline.pointsPerMinute).clamp(
      0.0,
      _timeline.totalMinutes,
    );
    return _timeline.start.add(
      Duration(milliseconds: (minutes * 60 * 1000).round()),
    );
  }

  DateTime _quantize(DateTime t) {
    final m = t.minute >= 30 ? 30 : 0;
    return DateTime(t.year, t.month, t.day, t.hour, m);
  }

  void _syncVisibleSlice() {
    if (!_hGrid.hasClients) return;
    final vp = _hGrid.position.viewportDimension;
    if (vp <= 0) return;
    final pad = vp; // one viewport of buffer each side
    final startX = (_hGrid.offset - pad).clamp(0.0, _timeline.totalWidth);
    final endX =
        (_hGrid.offset + vp + pad).clamp(0.0, _timeline.totalWidth);
    final nextStart = _quantize(_dateAtX(startX));
    final nextEnd = _quantize(_dateAtX(endX).add(const Duration(minutes: 30)));
    if (nextStart == _sliceStart && nextEnd == _sliceEnd) return;
    setState(() {
      _sliceStart = nextStart;
      _sliceEnd = nextEnd;
    });
  }

  void _onVChannels() {
    if (_syncingV || !_vGrid.hasClients) return;
    _syncingV = true;
    _vGrid.jumpTo(
      _vChannels.offset.clamp(0.0, _vGrid.position.maxScrollExtent),
    );
    _syncingV = false;
  }

  void _onVGrid() {
    if (_syncingV || !_vChannels.hasClients) return;
    _syncingV = true;
    _vChannels.jumpTo(
      _vGrid.offset.clamp(0.0, _vChannels.position.maxScrollExtent),
    );
    _syncingV = false;
  }

  void _scrollToNow() {
    if (_didInitialScroll) return;
    if (!_hGrid.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
      return;
    }
    final max = _hGrid.position.maxScrollExtent;
    if (max <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
      return;
    }
    _didInitialScroll = true;
    final target = (_timeline.xFor(_now) - 120).clamp(0.0, max);
    _hGrid.jumpTo(target);
    if (_hRuler.hasClients) {
      _hRuler.jumpTo(target.clamp(0.0, _hRuler.position.maxScrollExtent));
    }
    _syncVisibleSlice();
  }

  /// Tile only programmes overlapping [sliceStart, sliceEnd] - not the full day.
  ///
  /// Xtream often returns overlapping / duplicate listings for the same channel.
  /// We sort, then advance a cursor so cells never stack on the same x-range.
  List<_EpgCell> _cellsFor(
    List<EpgEntry> listings, {
    required DateTime sliceStart,
    required DateTime sliceEnd,
  }) {
    final from = sliceStart.isBefore(_timeline.start)
        ? _timeline.start
        : sliceStart;
    final to = sliceEnd.isAfter(_timeline.end) ? _timeline.end : sliceEnd;
    if (!to.isAfter(from)) return const [];

    final ordered = List<EpgEntry>.of(listings)
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        return b.stop.compareTo(a.stop); // longer first when same start
      });

    final cells = <_EpgCell>[];
    var cursor = from;
    for (final e in ordered) {
      if (!e.stop.isAfter(from) || !e.start.isBefore(to)) continue;
      // Clip into the remaining free range - drops dupes / overlaps.
      var start = e.start.isBefore(from) ? from : e.start;
      if (start.isBefore(cursor)) start = cursor;
      final stop = e.stop.isAfter(to) ? to : e.stop;
      if (!stop.isAfter(start)) continue;
      if (start.isAfter(cursor)) {
        cells.add(_EpgCell(
          entry: null,
          left: _timeline.xFor(cursor),
          width: _timeline.widthBetween(cursor, start),
          isGap: true,
        ));
      }
      cells.add(_EpgCell(
        entry: e,
        left: _timeline.xFor(start),
        width: _timeline.widthBetween(start, stop),
        isGap: false,
      ));
      cursor = stop;
    }
    if (cursor.isBefore(to)) {
      cells.add(_EpgCell(
        entry: null,
        left: _timeline.xFor(cursor),
        width: _timeline.widthBetween(cursor, to),
        isGap: true,
      ));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final streams = widget.streams;
    if (streams.isEmpty) {
      return Center(
        child: Text(
          'No streams in this view',
          style: GoogleFonts.plusJakartaSans(color: Colors.white60),
        ),
      );
    }

    final nowX = _timeline.xFor(_now);

    return Column(
      children: [
        SizedBox(
          height: _headerH,
          child: Row(
            children: [
              SizedBox(width: _channelColW),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hRuler,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: _timeline.totalWidth,
                    height: _headerH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final tick in _timeline.halfHourTicks)
                          if (!tick.isBefore(_sliceStart) &&
                              !tick.isAfter(_sliceEnd))
                            Positioned(
                              left: _timeline.xFor(tick),
                              top: 0,
                              bottom: 0,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _fmtTick(tick),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ForjaShellColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        Positioned(
                          left: nowX - 22,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Now',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _channelColW,
                child: Builder(
                  builder: (context) {
                    final list = ListView.builder(
                      controller: _vChannels,
                      physics: const ClampingScrollPhysics(),
                      itemExtent: _rowH,
                      itemCount: streams.length,
                      itemBuilder: (_, i) => _ChannelCell(
                        stream: streams[i],
                        ctrl: widget.ctrl,
                        listIndex: i,
                        onTap: () => widget.onPlay(streams[i]),
                      ),
                    );
                    if (!iptvUseTvFocus(context) || streams.isEmpty) {
                      return list;
                    }
                    return TvCatalogRow(
                      tabId: 'iptv',
                      rowId: 'epg-channels',
                      sortOrder: 10,
                      itemCount: streams.length,
                      orientation: ShellTvRowOrientation.vertical,
                      child: list,
                    );
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hGrid,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: _timeline.totalWidth,
                    child: Stack(
                      children: [
                        ListView.builder(
                          controller: _vGrid,
                          physics: const ClampingScrollPhysics(),
                          itemExtent: _rowH,
                          // ~2 rows above/below viewport - only those fetch EPG.
                          // ignore: deprecated_member_use
                          cacheExtent: _rowH * 2,
                          itemCount: streams.length,
                          itemBuilder: (_, i) {
                            final s = streams[i];
                            return SizedBox(
                              height: _rowH,
                              width: _timeline.totalWidth,
                              child: _ProgrammeRow(
                                future: widget.ctrl.guideEpgFor(s),
                                sliceStart: _sliceStart,
                                sliceEnd: _sliceEnd,
                                cellsFor: _cellsFor,
                                now: _now,
                                onTap: () => widget.onPlay(s),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          left: nowX,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 2,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmtTick(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ChannelCell extends StatefulWidget {
  const _ChannelCell({
    required this.stream,
    required this.ctrl,
    required this.onTap,
    this.listIndex,
  });

  final IptvStream stream;
  final IptvController ctrl;
  final VoidCallback onTap;
  final int? listIndex;

  @override
  State<_ChannelCell> createState() => _ChannelCellState();
}

class _ChannelCellState extends State<_ChannelCell> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final stream = widget.stream;
    final active = _hovered || _focused;
    return iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      listIndex: widget.listIndex,
      tvRowId: 'epg-channels',
      tvItemIndex: widget.listIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: Container(
            height: _kEpgRowH,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active
                  ? ForjaShellColors.inkHover
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: active
                      ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: 2.5,
                ),
                right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                if (stream.icon.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      stream.icon,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stackTrace) => const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.tv_rounded,
                          size: 18,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.tv_rounded,
                      size: 18,
                      color: Colors.white38,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stream.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: active
                          ? Colors.white
                          : ForjaShellColors.textSecondary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                ExcludeFocus(
                  excluding: iptvUseTvFocus(context),
                  child: IptvLiveFavoriteButton(
                    streamId: stream.streamId,
                    ctrl: widget.ctrl,
                    reveal: active,
                    iconSize: 14,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _ProgrammeRow extends StatelessWidget {
  const _ProgrammeRow({
    required this.future,
    required this.sliceStart,
    required this.sliceEnd,
    required this.cellsFor,
    required this.now,
    required this.onTap,
  });

  final Future<List<EpgEntry>> future;
  final DateTime sliceStart;
  final DateTime sliceEnd;
  final List<_EpgCell> Function(
    List<EpgEntry> listings, {
    required DateTime sliceStart,
    required DateTime sliceEnd,
  }) cellsFor;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: future,
      builder: (context, snap) {
        final cells = cellsFor(
          snap.data ?? const <EpgEntry>[],
          sliceStart: sliceStart,
          sliceEnd: sliceEnd,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final cell in cells)
              if (cell.width >= 2)
                Positioned(
                  left: cell.left,
                  width: cell.width,
                  top: 4,
                  bottom: 4,
                  child: cell.isGap
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      : _ProgrammeBlock(
                          entry: cell.entry!,
                          now: now,
                          width: cell.width,
                          onTap: onTap,
                        ),
                ),
          ],
        );
      },
    );
  }
}

class _ProgrammeBlock extends StatelessWidget {
  const _ProgrammeBlock({
    required this.entry,
    required this.now,
    required this.width,
    required this.onTap,
  });

  final EpgEntry entry;
  final DateTime now;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = !now.isBefore(entry.start) && now.isBefore(entry.stop);
    final past = !entry.stop.isAfter(now);
    final bg = live
        ? const Color(0xFF1E3A5F)
        : Colors.white.withValues(alpha: past ? 0.04 : 0.07);
    final border = live
        ? const Color(0xFF3B82F6).withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.08);

    // Tiny slices (overlap remnants / short spots) - color only, no Column.
    final showLabel = width >= 36;
    final showTime = width >= 64;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: showLabel
              ? EdgeInsets.fromLTRB(showTime ? 8 : 4, 4, showTime ? 8 : 4, 4)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.hardEdge,
          child: !showLabel
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title.isEmpty ? '-' : entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: past && !live
                              ? Colors.white54
                              : ForjaShellColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showTime)
                      Text(
                        _fmtTime(entry.start),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
