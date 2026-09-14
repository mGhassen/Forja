import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class EpgChannel {
  const EpgChannel({required this.id, required this.title, this.logoUrl});
  final String id;
  final String title;
  final String? logoUrl;
}

class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.title,
    required this.startMs,
    required this.endMs,
  });
  final String channelId;
  final String title;
  final int startMs;
  final int endMs;
}

/// Presentational EPG — channel column + time ruler + programme blocks.
/// Paint-only. Host owns fetch, focus, and play.
class EpgGuide extends StatefulWidget {
  const EpgGuide({
    super.key,
    required this.channels,
    required this.programmes,
    required this.windowStartMs,
    required this.windowEndMs,
    this.onChannelTap,
    this.onProgrammeTap,
    this.showNowLine = true,
    this.nowMs,
    this.pxPerMinute = 3.0,
    this.channelWidth = 168,
    this.rowHeight = 56,
    this.rulerHeight = 32,
  });

  final List<EpgChannel> channels;
  final List<EpgProgramme> programmes;
  final int windowStartMs;
  final int windowEndMs;
  final ValueChanged<EpgChannel>? onChannelTap;
  final ValueChanged<EpgProgramme>? onProgrammeTap;
  final bool showNowLine;
  final int? nowMs;
  final double pxPerMinute;
  final double channelWidth;
  final double rowHeight;
  final double rulerHeight;

  @override
  State<EpgGuide> createState() => _EpgGuideState();
}

class _EpgGuideState extends State<EpgGuide> {
  final _hRuler = ScrollController();
  final _hGrid = ScrollController();
  final _vChannels = ScrollController();
  final _vGrid = ScrollController();
  var _syncH = false;
  var _syncV = false;

  @override
  void initState() {
    super.initState();
    _hRuler.addListener(_onHRuler);
    _hGrid.addListener(_onHGrid);
    _vChannels.addListener(_onVChannels);
    _vGrid.addListener(_onVGrid);
  }

  void _onHRuler() => _mirror(_hRuler, _hGrid, h: true);
  void _onHGrid() => _mirror(_hGrid, _hRuler, h: true);
  void _onVChannels() => _mirror(_vChannels, _vGrid, h: false);
  void _onVGrid() => _mirror(_vGrid, _vChannels, h: false);

  void _mirror(ScrollController from, ScrollController to, {required bool h}) {
    if ((h ? _syncH : _syncV) || !to.hasClients) return;
    if (h) {
      _syncH = true;
    } else {
      _syncV = true;
    }
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    if (h) {
      _syncH = false;
    } else {
      _syncV = false;
    }
  }

  @override
  void dispose() {
    _hRuler..removeListener(_onHRuler)..dispose();
    _hGrid..removeListener(_onHGrid)..dispose();
    _vChannels..removeListener(_onVChannels)..dispose();
    _vGrid..removeListener(_onVGrid)..dispose();
    super.dispose();
  }

  double get _totalWidth {
    final mins =
        (widget.windowEndMs - widget.windowStartMs).clamp(1, 1 << 30) / 60000.0;
    return mins * widget.pxPerMinute;
  }

  double _xFor(int ms) {
    final c = ms.clamp(widget.windowStartMs, widget.windowEndMs);
    return (c - widget.windowStartMs) / 60000.0 * widget.pxPerMinute;
  }

  List<DateTime> _ticks() {
    final start = DateTime.fromMillisecondsSinceEpoch(widget.windowStartMs);
    final end = DateTime.fromMillisecondsSinceEpoch(widget.windowEndMs);
    var cur = DateTime(start.year, start.month, start.day, start.hour,
        start.minute >= 30 ? 30 : 0);
    if (cur.isBefore(start)) cur = cur.add(const Duration(minutes: 30));
    final out = <DateTime>[];
    while (!cur.isAfter(end)) {
      out.add(cur);
      cur = cur.add(const Duration(minutes: 30));
    }
    return out;
  }

  Map<String, List<EpgProgramme>> _byChannel() {
    final map = <String, List<EpgProgramme>>{};
    for (final p in widget.programmes) {
      if (p.endMs <= widget.windowStartMs || p.startMs >= widget.windowEndMs) {
        continue;
      }
      (map[p.channelId] ??= []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final showNow = widget.showNowLine &&
        now >= widget.windowStartMs &&
        now <= widget.windowEndMs;
    final byChannel = _byChannel();
    final width = _totalWidth;
    final tickStyle = GoogleFonts.plusJakartaSans(
      color: ForjaShellColors.textSecondary,
      fontSize: 11,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: widget.channelWidth,
          child: Column(children: [
            SizedBox(height: widget.rulerHeight),
            Expanded(
              child: ListView.builder(
                controller: _vChannels,
                itemCount: widget.channels.length,
                itemExtent: widget.rowHeight,
                itemBuilder: (_, i) => _channelCell(widget.channels[i]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Column(children: [
            SizedBox(
              height: widget.rulerHeight,
              child: ListView(
                controller: _hRuler,
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(
                    width: width,
                    height: widget.rulerHeight,
                    child: Stack(children: [
                      for (final t in _ticks())
                        Positioned(
                          left: _xFor(t.millisecondsSinceEpoch),
                          top: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${t.hour.toString().padLeft(2, '0')}:'
                              '${t.minute.toString().padLeft(2, '0')}',
                              style: tickStyle,
                            ),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _hGrid,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Stack(children: [
                    ListView.builder(
                      controller: _vGrid,
                      itemCount: widget.channels.length,
                      itemExtent: widget.rowHeight,
                      itemBuilder: (_, i) => _programmeRow(
                        byChannel[widget.channels[i].id] ?? const [],
                        width,
                      ),
                    ),
                    if (showNow)
                      Positioned(
                        left: _xFor(now),
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 2,
                            color: ForjaShellColors.brandGreen
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _channelCell(EpgChannel ch) {
    final logo = ch.logoUrl?.trim();
    return InkWell(
      onTap: widget.onChannelTap == null ? null : () => widget.onChannelTap!(ch),
      child: Container(
        height: widget.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: ForjaShellColors.borderSubtle),
            right: BorderSide(color: ForjaShellColors.borderSubtle),
          ),
        ),
        child: Row(children: [
          if (logo != null && logo.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ForjaNetworkImage(
                url: logo,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                error: const SizedBox(width: 28, height: 28),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              ch.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: ForjaShellColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _programmeRow(List<EpgProgramme> programmes, double totalWidth) {
    final kids = <Widget>[
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    ];
    for (final p in programmes) {
      final left =
          _xFor(p.startMs.clamp(widget.windowStartMs, widget.windowEndMs));
      final right =
          _xFor(p.endMs.clamp(widget.windowStartMs, widget.windowEndMs));
      final w = (right - left).clamp(0.0, totalWidth);
      if (w < 4) continue;
      kids.add(Positioned(
        left: left,
        width: w,
        top: 4,
        bottom: 4,
        child: Material(
          color: ForjaShellColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: widget.onProgrammeTap == null
                ? null
                : () => widget.onProgrammeTap!(p),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return SizedBox(
      height: widget.rowHeight,
      width: totalWidth,
      child: Stack(children: kids),
    );
  }
}
