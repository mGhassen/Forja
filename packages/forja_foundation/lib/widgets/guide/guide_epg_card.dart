import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';

/// Stable height for the full EPG card in the channel-guide header.
const double kGuideEpgCardHeight = 132;

/// Taller shell when the NEXT programme row is shown below the current entry.
const double kGuideEpgCardHeightWithNext = 156;

double _guideEpgCardHeightOf(BuildContext context, {required bool withNext}) =>
    GuideChromeStyle.len(
      context,
      withNext ? kGuideEpgCardHeightWithNext : kGuideEpgCardHeight,
    );

class GuideEpgCard extends StatefulWidget {
  const GuideEpgCard({
    super.key,
    required this.future,
    this.compact = false,
    this.floating = false,
  });

  final Future<List<GuideEpgProgramme>> future;
  final bool compact;
  final bool floating;

  @override
  State<GuideEpgCard> createState() => _GuideEpgCardState();
}

class _GuideEpgCardState extends State<GuideEpgCard> {
  Timer? _tick;

  static Color get _accent => GuideChromeStyle.accent;
  static Color get _live => GuideChromeStyle.liveBadge;

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

  static double _progress(GuideEpgProgramme e) {
    final now = DateTime.now();
    final total = e.stop.difference(e.start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(e.start).inSeconds.clamp(0, total);
    return elapsed / total;
  }

  Widget _fullCardShell({
    required Widget child,
    double? height,
  }) {
    final h = height ?? _guideEpgCardHeightOf(context, withNext: false);
    return SizedBox(
      height: h,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          GuideChromeStyle.len(context, 10),
          GuideChromeStyle.len(context, 4),
          GuideChromeStyle.len(context, 10),
          GuideChromeStyle.len(context, 8),
        ),
        padding: EdgeInsets.fromLTRB(
          GuideChromeStyle.len(context, 12),
          GuideChromeStyle.len(context, 10),
          GuideChromeStyle.len(context, 12),
          GuideChromeStyle.len(context, 10),
        ),
        decoration: BoxDecoration(
          color: GuideChromeStyle.surfaceGlass,
          borderRadius: BorderRadius.circular(GuideChromeStyle.len(context, 12)),
          border: Border.all(color: GuideChromeStyle.border),
        ),
        child: ClipRect(
          child: child,
        ),
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
            fontSize: GuideChromeStyle.type(context, 11),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GuideEpgProgramme>>(
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

        final nowEntry = data.cast<GuideEpgProgramme?>().firstWhere(
              (e) => e!.isNow,
              orElse: () => data.first,
            )!;
        final nextEntry = data.cast<GuideEpgProgramme?>().firstWhere(
              (e) => e != null && !e.isNow && e.start.isAfter(DateTime.now()),
              orElse: () => null,
            );
        final laterEntry = data.cast<GuideEpgProgramme?>().firstWhere(
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
          height: _guideEpgCardHeightOf(context, withNext: nextEntry != null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Badge(
                    label: nowEntry.isNow ? 'LIVE' : 'NEXT',
                    color: nowEntry.isNow ? _live : _accent,
                  ),
                  SizedBox(width: GuideChromeStyle.len(context, 8)),
                  Text(
                    '${_fmtTime(nowEntry.start)} – ${_fmtTime(nowEntry.stop)}',
                    style: GoogleFonts.spaceMono(
                      color: Colors.white60,
                      fontSize: GuideChromeStyle.type(context, 11),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              SizedBox(height: GuideChromeStyle.len(context, 6)),
              CrossfadeSwap(
                child: Text(
                  nowEntry.title.isEmpty ? '-' : nowEntry.title,
                  key: ValueKey(nowEntry.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: GuideChromeStyle.type(context, 13),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              if (nowEntry.isNow) ...[
                SizedBox(height: GuideChromeStyle.len(context, 8)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    GuideChromeStyle.len(context, 3),
                  ),
                  child: LinearProgressIndicator(
                    value: _progress(nowEntry).clamp(0.0, 1.0),
                    minHeight: GuideChromeStyle.len(context, 3),
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: _accent,
                  ),
                ),
              ],
              if (nowEntry.description.isNotEmpty) ...[
                SizedBox(height: GuideChromeStyle.len(context, 6)),
                Text(
                  nowEntry.description,
                  maxLines: nextEntry != null ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: GuideChromeStyle.type(context, 11),
                    height: 1.35,
                  ),
                ),
              ],
              if (nextEntry != null) ...[
                SizedBox(height: GuideChromeStyle.len(context, 10)),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                SizedBox(height: GuideChromeStyle.len(context, 8)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Badge(label: 'NEXT', color: Colors.white38, small: true),
                    SizedBox(width: GuideChromeStyle.len(context, 8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmtTime(nextEntry.start),
                            style: GoogleFonts.spaceMono(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: GuideChromeStyle.type(context, 10),
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
                              fontSize: GuideChromeStyle.type(context, 11),
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
    required GuideEpgProgramme nowEntry,
    required GuideEpgProgramme? nextEntry,
    required GuideEpgProgramme? laterEntry,
  }) {
    // Fill + soft edge live on [GuideFloatingEpg] — content only here.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        GuideChromeStyle.len(context, 14),
        GuideChromeStyle.len(context, 12),
        GuideChromeStyle.len(context, 14),
        GuideChromeStyle.len(context, 12),
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
              SizedBox(width: GuideChromeStyle.len(context, 10)),
              Text(
                '${_fmtTime(nowEntry.start)} – ${_fmtTime(nowEntry.stop)}',
                style: GoogleFonts.spaceMono(
                  color: Colors.white60,
                  fontSize: GuideChromeStyle.type(context, 13),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: GuideChromeStyle.len(context, 8)),
          CrossfadeSwap(
            child: Text(
              nowEntry.title.isEmpty ? '-' : nowEntry.title,
              key: ValueKey('float-${nowEntry.title}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: GuideChromeStyle.type(context, 16),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          if (nowEntry.isNow) ...[
            SizedBox(height: GuideChromeStyle.len(context, 10)),
            ClipRRect(
              borderRadius: BorderRadius.circular(
                GuideChromeStyle.len(context, 3),
              ),
              child: LinearProgressIndicator(
                value: _progress(nowEntry).clamp(0.0, 1.0),
                minHeight: GuideChromeStyle.len(context, 4),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: _accent,
              ),
            ),
          ],
          if (nowEntry.description.isNotEmpty) ...[
            SizedBox(height: GuideChromeStyle.len(context, 8)),
            HeroOverviewText(
              overview: nowEntry.description,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: GuideChromeStyle.type(context, 12),
                height: 1.35,
              ),
            ),
          ],
          if (nextEntry != null) ...[
            SizedBox(height: GuideChromeStyle.len(context, 12)),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            SizedBox(height: GuideChromeStyle.len(context, 10)),
            _floatingUpcomingRow(label: 'NEXT', entry: nextEntry),
          ],
          if (laterEntry != null) ...[
            SizedBox(height: GuideChromeStyle.len(context, 8)),
            _floatingUpcomingRow(label: 'LATER', entry: laterEntry),
          ],
        ],
      ),
    );
  }

  Widget _floatingUpcomingRow({
    required String label,
    required GuideEpgProgramme entry,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(label: label, color: Colors.white38, medium: true),
        SizedBox(width: GuideChromeStyle.len(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmtTime(entry.start)} – ${_fmtTime(entry.stop)}',
                style: GoogleFonts.spaceMono(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: GuideChromeStyle.type(context, 12),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(height: GuideChromeStyle.len(context, 2)),
              CrossfadeSwap(
                child: Text(
                  entry.title.isEmpty ? '-' : entry.title,
                  key: ValueKey('next-${entry.title}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: GuideChromeStyle.type(context, 13),
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
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

  final GuideEpgProgramme entry;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: GuideChromeStyle.len(context, 3)),
      child: Row(
        children: [
          _Badge(
            label: isLive ? 'NOW' : 'NEXT',
            color: isLive ? const Color(0xFFEF4444) : GuideChromeStyle.accent,
            small: true,
          ),
          SizedBox(width: GuideChromeStyle.len(context, 6)),
          Expanded(
            child: CrossfadeSwap(
              child: Text(
                entry.title.isEmpty ? '-' : entry.title,
                key: ValueKey(entry.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: GuideChromeStyle.type(context, 10),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-right programme guide overlay for the IPTV player.
///
/// Dark frosted glass (blur + light tint), soft outer feather, no stroke —
/// same family as portal probe / Sources glass. Small temporary card only;
/// full-height channel guide stays flat translucent (no blur over video).
///
/// [maxWidth] must already be densified by the caller ([GuideChromeStyle.len] /
/// [GuideChromeStyle.floatingEpgMaxWidthOf] / peek [epgPeekWidthOf]) — do not
/// scale again here.
class GuideFloatingEpg extends StatelessWidget {
  const GuideFloatingEpg({
    super.key,
    required this.future,
    required this.maxWidth,
  });

  final Future<List<GuideEpgProgramme>> future;
  final double maxWidth;

  /// Matches the historical floating EPG frost strength.
  static const double _blurSigma = 22;

  @override
  Widget build(BuildContext context) {
    final radius = GuideChromeStyle.len(context, 12);
    final r = BorderRadius.circular(radius);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: GuideChromeStyle.len(context, 28),
              spreadRadius: GuideChromeStyle.len(context, -2),
              offset: Offset(0, GuideChromeStyle.len(context, 6)),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: GuideChromeStyle.len(context, 14),
            ),
          ],
        ),
        child: ForjaFrostedPanel(
          enableBlur: true,
          blurSigma: _blurSigma,
          borderRadius: r,
          child: GuideEpgCard(future: future, floating: true),
        ),
      ),
    );
  }
}

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
    final fontSize = GuideChromeStyle.type(
      context,
      large ? 10.0 : (medium ? 9.0 : (small ? 8.0 : 9.0)),
    );
    final hPad = GuideChromeStyle.len(
      context,
      large ? 7.0 : (medium ? 6.0 : (small ? 5.0 : 6.0)),
    );
    final vPad = GuideChromeStyle.len(
      context,
      large ? 3.0 : (medium ? 2.0 : (small ? 1.0 : 2.0)),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: small || medium ? 0.35 : 0.85),
        borderRadius: BorderRadius.circular(GuideChromeStyle.len(context, 4)),
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
