import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/epg_guide_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';
import 'package:google_fonts/google_fonts.dart';

/// One channel row in [CatalogEpgGuide].
class CatalogEpgChannel {
  const CatalogEpgChannel({
    required this.id,
    required this.title,
    this.imageUrl = '',
    this.programmes = const [],
    this.payload,
  });

  final String id;
  final String title;
  final String imageUrl;

  /// Prefetched programmes (optional). Empty → [CatalogEpgGuide.loadProgrammes].
  final List<GuideEpgProgramme> programmes;

  /// Opaque host payload (e.g. pack item map).
  final Object? payload;
}

/// Pure layout maths for the catalog EPG timeline.
class CatalogEpgTimeline {
  CatalogEpgTimeline({
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

  /// Default Live catalog window: 6h behind → 24h ahead, floored to half-hour.
  static CatalogEpgTimeline live({
    DateTime? now,
    double hoursBehind = 6,
    double hoursAhead = 24,
  }) {
    final n = now ?? DateTime.now();
    final flooredMinute = n.minute >= 30 ? 30 : 0;
    final anchor = DateTime(n.year, n.month, n.day, n.hour, flooredMinute);
    final start =
        anchor.subtract(Duration(minutes: (hoursBehind * 60).round()));
    final end = start.add(
      Duration(minutes: ((hoursBehind + hoursAhead) * 60).round()),
    );
    return CatalogEpgTimeline(start: start, end: end);
  }
}

/// Desktop Live catalog EPG: sticky channels + sticky ruler + programme blocks.
class CatalogEpgGuide extends StatefulWidget {
  const CatalogEpgGuide({
    super.key,
    required this.channels,
    required this.onChannelTap,
    this.loadProgrammes,
    this.highlightChannelId,
    this.accessoryBuilder,
    this.timeline,
    this.emptyTitle = 'No channels in this view',
  });

  final List<CatalogEpgChannel> channels;
  final ValueChanged<CatalogEpgChannel> onChannelTap;

  /// Lazy EPG fetch per channel (stable Future for FutureBuilder).
  final Future<List<GuideEpgProgramme>> Function(CatalogEpgChannel channel)?
      loadProgrammes;

  final String? highlightChannelId;

  /// Optional trailing control on the channel rail (e.g. favorite).
  final Widget? Function(
    CatalogEpgChannel channel, {
    required bool active,
  })? accessoryBuilder;

  final CatalogEpgTimeline? timeline;
  final String emptyTitle;

  @override
  State<CatalogEpgGuide> createState() => _CatalogEpgGuideState();
}

class _CatalogEpgGuideState extends State<CatalogEpgGuide> {
  late CatalogEpgTimeline _timeline;
  final _hRuler = ScrollController();
  final _hGrid = ScrollController();
  final _vChannels = ScrollController();
  final _vGrid = ScrollController();
  bool _syncingH = false;
  bool _syncingV = false;
  bool _didInitialScroll = false;
  Timer? _nowTick;
  DateTime _now = DateTime.now();
  late DateTime _sliceStart;
  late DateTime _sliceEnd;
  final Map<String, Future<List<GuideEpgProgramme>>> _futures = {};

  @override
  void initState() {
    super.initState();
    _timeline = widget.timeline ?? CatalogEpgTimeline.live(now: _now);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNow();
      _prefetchVisible();
    });
  }

  /// Kick EPG for the first screenful so rows do not wait on scroll build.
  void _prefetchVisible() {
    final channels = widget.channels;
    if (channels.isEmpty || widget.loadProgrammes == null) return;
    final n = channels.length < 16 ? channels.length : 16;
    for (var i = 0; i < n; i++) {
      _futureFor(channels[i]);
    }
  }

  @override
  void didUpdateWidget(covariant CatalogEpgGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeline != widget.timeline && widget.timeline != null) {
      _timeline = widget.timeline!;
    }
    if (oldWidget.channels != widget.channels) {
      // Drop futures for removed ids; keep cache for reused channels.
      final ids = {for (final c in widget.channels) c.id};
      _futures.removeWhere((k, _) => !ids.contains(k));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prefetchVisible();
      });
    }
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

  Future<List<GuideEpgProgramme>> _futureFor(CatalogEpgChannel channel) {
    if (channel.programmes.isNotEmpty) {
      return Future.value(channel.programmes);
    }
    final loader = widget.loadProgrammes;
    if (loader == null) return Future.value(const []);
    return _futures.putIfAbsent(channel.id, () => loader(channel));
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
    final pad = vp;
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
    _scrollToHighlightedChannel();
    _syncVisibleSlice();
  }

  void _scrollToHighlightedChannel() {
    final id = widget.highlightChannelId;
    if (id == null || id.isEmpty) return;
    final idx = widget.channels.indexWhere((c) => c.id == id);
    if (idx < 0 || !_vChannels.hasClients) return;
    final target =
        (idx * EpgGuideTokens.rowHeight).clamp(0.0, _vChannels.position.maxScrollExtent);
    _syncingV = true;
    _vChannels.jumpTo(target);
    if (_vGrid.hasClients) {
      _vGrid.jumpTo(target.clamp(0.0, _vGrid.position.maxScrollExtent));
    }
    _syncingV = false;
  }

  List<_EpgCell> _cellsFor(
    List<GuideEpgProgramme> listings, {
    required DateTime sliceStart,
    required DateTime sliceEnd,
  }) {
    final from = sliceStart.isBefore(_timeline.start)
        ? _timeline.start
        : sliceStart;
    final to = sliceEnd.isAfter(_timeline.end) ? _timeline.end : sliceEnd;
    if (!to.isAfter(from)) return const [];

    final ordered = List<GuideEpgProgramme>.of(listings)
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        return b.stop.compareTo(a.stop);
      });

    final cells = <_EpgCell>[];
    var cursor = from;
    for (final e in ordered) {
      if (!e.stop.isAfter(from) || !e.start.isBefore(to)) continue;
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
    final channels = widget.channels;
    if (channels.isEmpty) {
      return Center(
        child: Text(
          widget.emptyTitle,
          style: GoogleFonts.plusJakartaSans(color: Colors.white60),
        ),
      );
    }

    final nowX = _timeline.xFor(_now);

    return Column(
      children: [
        SizedBox(
          height: EpgGuideTokens.headerHeight,
          child: Row(
            children: [
              const SizedBox(width: EpgGuideTokens.columnWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hRuler,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: _timeline.totalWidth,
                    height: EpgGuideTokens.headerHeight,
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
                width: EpgGuideTokens.columnWidth,
                child: ListView.builder(
                  controller: _vChannels,
                  physics: const ClampingScrollPhysics(),
                  itemExtent: EpgGuideTokens.rowHeight,
                  itemCount: channels.length,
                  itemBuilder: (_, i) => _ChannelCell(
                    channel: channels[i],
                    listIndex: i,
                    highlighted: channels[i].id == widget.highlightChannelId,
                    onTap: () => widget.onChannelTap(channels[i]),
                    accessoryBuilder: widget.accessoryBuilder,
                  ),
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
                          scrollCacheExtent: ScrollCacheExtent.pixels(EpgGuideTokens.rowHeight * 12), controller: _vGrid,
                          physics: const ClampingScrollPhysics(),
                          itemExtent: EpgGuideTokens.rowHeight,
                          itemCount: channels.length,
                          itemBuilder: (_, i) {
                            final ch = channels[i];
                            return SizedBox(
                              height: EpgGuideTokens.rowHeight,
                              width: _timeline.totalWidth,
                              child: _ProgrammeRow(
                                future: _futureFor(ch),
                                sliceStart: _sliceStart,
                                sliceEnd: _sliceEnd,
                                cellsFor: _cellsFor,
                                now: _now,
                                onTap: () => widget.onChannelTap(ch),
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

class _EpgCell {
  const _EpgCell({
    required this.entry,
    required this.left,
    required this.width,
    required this.isGap,
  });

  final GuideEpgProgramme? entry;
  final double left;
  final double width;
  final bool isGap;
}

class _ChannelCell extends StatefulWidget {
  const _ChannelCell({
    required this.channel,
    required this.onTap,
    this.listIndex,
    this.highlighted = false,
    this.accessoryBuilder,
  });

  final CatalogEpgChannel channel;
  final VoidCallback onTap;
  final int? listIndex;
  final bool highlighted;
  final Widget? Function(
    CatalogEpgChannel channel, {
    required bool active,
  })? accessoryBuilder;

  @override
  State<_ChannelCell> createState() => _ChannelCellState();
}

class _ChannelCellState extends State<_ChannelCell> {
  bool _hovered = false;
  bool _focused = false;

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final active = _hovered || _focused;
    final selected = widget.highlighted && !active;
    final accessory = widget.accessoryBuilder?.call(
      channel,
      active: active,
    );

    final body = Container(
      height: EpgGuideTokens.rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active
            ? ForjaShellColors.inkHover
            : selected
                ? ForjaShellColors.chipSelectedBg
                : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: active
                ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
                : selected
                    ? ForjaShellColors.chipSelectedBorder
                    : Colors.transparent,
            width: 2.5,
          ),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          if (channel.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: ForjaNetworkImage(
                key: ValueKey(channel.imageUrl),
                url: channel.imageUrl,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                useOldImageOnUrlChange: false,
                error: const SizedBox(
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
              channel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: active || selected
                    ? Colors.white
                    : ForjaShellColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    active || selected ? FontWeight.w700 : FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
          if (accessory != null)
            ExcludeFocus(
              excluding: _tv,
              child: accessory,
            ),
        ],
      ),
    );

    if (!_tv) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: shellRoundedInkHost(
          radius: 0,
          onTap: widget.onTap,
          suppressInkHover: true,
          child: body,
        ),
      );
    }

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      listIndex: widget.listIndex,
      tvRowId: 'epg-channels',
      tvItemIndex: widget.listIndex,
      tvZone: ShellPaintTvZone.row,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: body,
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

  final Future<List<GuideEpgProgramme>> future;
  final DateTime sliceStart;
  final DateTime sliceEnd;
  final List<_EpgCell> Function(
    List<GuideEpgProgramme> listings, {
    required DateTime sliceStart,
    required DateTime sliceEnd,
  }) cellsFor;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GuideEpgProgramme>>(
      future: future,
      builder: (context, snap) {
        final cells = cellsFor(
          snap.data ?? const <GuideEpgProgramme>[],
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

  final GuideEpgProgramme entry;
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
