import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single EPG programme for guide paint.
class GuideEpgEntry {
  final String title;
  final String description;
  final DateTime start;
  final DateTime stop;

  const GuideEpgEntry({
    required this.title,
    required this.description,
    required this.start,
    required this.stop,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(stop);
  }
}

/// Stable height for the full EPG card in the channel-guide header.
const double kGuideEpgCardHeight = 132;

/// Taller shell when the NEXT programme row is shown below the current entry.
const double kGuideEpgCardHeightWithNext = 156;

/// Migration aliases.
const double kIptvGuideEpgCardHeight = kGuideEpgCardHeight;
const double kIptvGuideEpgCardHeightWithNext = kGuideEpgCardHeightWithNext;

abstract final class _GuideShell {
  static Color get accent => ForjaShellColors.cinematic.navUnderline;
  static Color get live => const Color(0xFFEF4444);
  static Color get border => ForjaShellColors.cinematic.borderSubtle;
  static Color get surfaceMuted => Colors.white.withValues(alpha: 0.04);
}

/// Presentational EPG card — host supplies [future] of [GuideEpgEntry].
class GuideEpgCard extends StatefulWidget {
  const GuideEpgCard({
    super.key,
    required this.future,
    this.compact = false,
    this.floating = false,
  });

  final Future<List<GuideEpgEntry>> future;
  final bool compact;
  final bool floating;

  @override
  State<GuideEpgCard> createState() => _GuideEpgCardState();
}

/// Migration alias — prefer [GuideEpgCard].
typedef IptvGuideEpgCard = GuideEpgCard;

class _GuideEpgCardState extends State<GuideEpgCard> {
  Timer? _tick;

  static Color get _accent => _GuideShell.accent;
  static Color get _live => _GuideShell.live;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static double _progress(GuideEpgEntry e) {
    final now = DateTime.now();
    final total = e.stop.difference(e.start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(e.start).inSeconds.clamp(0, total);
    return elapsed / total;
  }

  Widget _fullCardShell({
    required Widget child,
    double height = kGuideEpgCardHeight,
  }) {
    return SizedBox(
      height: height,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _GuideShell.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _GuideShell.border),
        ),
        child: ClipRect(child: child),
      ),
    );
  }

  Widget _fullCardPlaceholder(String message) {
    return _fullCardShell(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GuideEpgEntry>>(
      future: widget.future,
      builder: (context, snap) {
        if (widget.compact) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) return const SizedBox.shrink();
        } else if (widget.floating) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) return const SizedBox.shrink();
        } else {
          if (snap.connectionState != ConnectionState.done) {
            return _fullCardPlaceholder('Loading guide…');
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) return _fullCardPlaceholder('No guide data');
        }

        final data = snap.data ?? const [];

        final nowEntry = data.cast<GuideEpgEntry?>().firstWhere(
              (e) => e!.isNow,
              orElse: () => data.first,
            )!;
        final nextEntry = data.cast<GuideEpgEntry?>().firstWhere(
              (e) => e != null && !e.isNow && e.start.isAfter(DateTime.now()),
              orElse: () => null,
            );
        final laterEntry = data.cast<GuideEpgEntry?>().firstWhere(
              (e) =>
                  e != null &&
                  !e.isNow &&
                  e.start.isAfter(DateTime.now()) &&
                  e != nextEntry,
              orElse: () => null,
            );

        if (widget.compact) {
          return _CompactEpgRow(entry: nowEntry, isLive: nowEntry.isNow);
        }

        if (widget.floating) {
          return _floatingCard(
            nowEntry: nowEntry,
            nextEntry: nextEntry,
            laterEntry: laterEntry,
          );
        }

        return _fullCardShell(
          height: nextEntry != null
              ? kGuideEpgCardHeightWithNext
              : kGuideEpgCardHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Badge(
                    label: nowEntry.isNow ? 'LIVE' : 'NEXT',
                    color: nowEntry.isNow ? _live : _accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_fmtTime(nowEntry.start)} – ${_fmtTime(nowEntry.stop)}',
                    style: GoogleFonts.spaceMono(
                      color: Colors.white60,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                nowEntry.title.isEmpty ? '-' : nowEntry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (nowEntry.isNow) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progress(nowEntry).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: _accent,
                  ),
                ),
              ],
              if (nowEntry.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  nowEntry.description,
                  maxLines: nextEntry != null ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
              if (nextEntry != null) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Badge(label: 'NEXT', color: Colors.white38, small: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmtTime(nextEntry.start),
                            style: GoogleFonts.spaceMono(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            nextEntry.title.isEmpty ? '-' : nextEntry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _floatingCard({
    required GuideEpgEntry nowEntry,
    required GuideEpgEntry? nextEntry,
    required GuideEpgEntry? laterEntry,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _GuideShell.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _GuideShell.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Badge(
                label: nowEntry.isNow ? 'LIVE' : 'NEXT',
                color: nowEntry.isNow ? _live : _accent,
                large: true,
              ),
              const SizedBox(width: 10),
              Text(
                '${_fmtTime(nowEntry.start)} – ${_fmtTime(nowEntry.stop)}',
                style: GoogleFonts.spaceMono(
                  color: Colors.white60,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nowEntry.title.isEmpty ? '-' : nowEntry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (nowEntry.isNow) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progress(nowEntry).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: _accent,
              ),
            ),
          ],
          if (nowEntry.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            HeroOverviewText(
              overview: nowEntry.description,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (nextEntry != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 10),
            _floatingUpcomingRow(label: 'NEXT', entry: nextEntry),
          ],
          if (laterEntry != null) ...[
            const SizedBox(height: 8),
            _floatingUpcomingRow(label: 'LATER', entry: laterEntry),
          ],
        ],
      ),
    );
  }

  Widget _floatingUpcomingRow({
    required String label,
    required GuideEpgEntry entry,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(label: label, color: Colors.white38, medium: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmtTime(entry.start)} – ${_fmtTime(entry.stop)}',
                style: GoogleFonts.spaceMono(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.title.isEmpty ? '-' : entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactEpgRow extends StatelessWidget {
  const _CompactEpgRow({required this.entry, required this.isLive});

  final GuideEpgEntry entry;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          _Badge(
            label: isLive ? 'NOW' : 'NEXT',
            color: isLive ? const Color(0xFFEF4444) : _GuideShell.accent,
            small: true,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.title.isEmpty ? '-' : entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-right programme guide overlay.
class FloatingEpg extends StatelessWidget {
  const FloatingEpg({
    super.key,
    required this.future,
    required this.maxWidth,
  });

  final Future<List<GuideEpgEntry>> future;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: GuideEpgCard(future: future, floating: true),
      ),
    );
  }
}

/// Migration alias — prefer [FloatingEpg].
typedef IptvFloatingEpg = FloatingEpg;

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.small = false,
    this.medium = false,
    this.large = false,
  });

  final String label;
  final Color color;
  final bool small;
  final bool medium;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? 10.0 : (medium ? 9.0 : (small ? 8.0 : 9.0));
    final hPad = large ? 7.0 : (medium ? 6.0 : (small ? 5.0 : 6.0));
    final vPad = large ? 3.0 : (medium ? 2.0 : (small ? 1.0 : 2.0));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: small || medium ? 0.35 : 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Barrel name for guide EPG paint.
typedef GuideEpgUi = GuideEpgCard;
