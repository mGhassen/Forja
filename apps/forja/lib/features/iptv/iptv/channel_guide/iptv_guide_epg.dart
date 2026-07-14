import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';

import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';

/// Memoized short-EPG fetches for the in-player channel guide.
class IptvGuideEpgCache {
  IptvGuideEpgCache(this.portal);

  final VerifiedPortal portal;
  final Map<String, Future<List<EpgEntry>>> _cache = {};

  Future<List<EpgEntry>> load(IptvStream stream, {int limit = 6}) {
    final streamId = stream.streamId;
    final epgId = stream.epgChannelId;
    if (streamId.isEmpty && epgId.isEmpty) {
      return Future.value(const []);
    }
    final key = '${streamId.isEmpty ? epgId : streamId}:$epgId:$limit';
    return _cache.putIfAbsent(key, () async {
      if (streamId.isNotEmpty) {
        final rows =
            await IptvClient.shortEpg(portal.portal, streamId, limit: limit);
        if (rows.isNotEmpty) return rows;
      }
      if (epgId.isNotEmpty && epgId != streamId) {
        return IptvClient.shortEpg(portal.portal, epgId, limit: limit);
      }
      return const [];
    });
  }

  void clear() => _cache.clear();
}

/// Stable height for the full EPG card in the channel-guide header.
const double kIptvGuideEpgCardHeight = 132;

/// Taller shell when the NEXT programme row is shown below the current entry.
const double kIptvGuideEpgCardHeightWithNext = 156;

class IptvGuideEpgCard extends StatefulWidget {
  const IptvGuideEpgCard({
    super.key,
    required this.future,
    this.compact = false,
    this.floating = false,
  });

  final Future<List<EpgEntry>> future;
  final bool compact;
  final bool floating;

  @override
  State<IptvGuideEpgCard> createState() => _IptvGuideEpgCardState();
}

class _IptvGuideEpgCardState extends State<IptvGuideEpgCard> {
  Timer? _tick;

  static Color get _accent => IptvShellStyle.accent;
  static Color get _live => IptvShellStyle.liveBadge;

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

  static double _progress(EpgEntry e) {
    final now = DateTime.now();
    final total = e.stop.difference(e.start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(e.start).inSeconds.clamp(0, total);
    return elapsed / total;
  }

  Widget _fullCardShell({
    required Widget child,
    double height = kIptvGuideEpgCardHeight,
  }) {
    return SizedBox(
      height: height,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: IptvShellStyle.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IptvShellStyle.border),
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
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
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

        final nowEntry = data.cast<EpgEntry?>().firstWhere(
              (e) => e!.isNow,
              orElse: () => data.first,
            )!;
        final nextEntry = data.cast<EpgEntry?>().firstWhere(
              (e) => e != null && !e.isNow && e.start.isAfter(DateTime.now()),
              orElse: () => null,
            );
        final laterEntry = data.cast<EpgEntry?>().firstWhere(
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
              ? kIptvGuideEpgCardHeightWithNext
              : kIptvGuideEpgCardHeight,
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
                nowEntry.title.isEmpty ? '—' : nowEntry.title,
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
                            nextEntry.title.isEmpty ? '—' : nextEntry.title,
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
    required EpgEntry nowEntry,
    required EpgEntry? nextEntry,
    required EpgEntry? laterEntry,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: IptvShellStyle.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IptvShellStyle.border),
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
            nowEntry.title.isEmpty ? '—' : nowEntry.title,
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
    required EpgEntry entry,
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
                entry.title.isEmpty ? '—' : entry.title,
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

  final EpgEntry entry;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          _Badge(
            label: isLive ? 'NOW' : 'NEXT',
            color: isLive ? const Color(0xFFEF4444) : IptvShellStyle.accent,
            small: true,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.title.isEmpty ? '—' : entry.title,
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

/// Bottom-right programme guide overlay for the IPTV player.
class IptvFloatingEpg extends StatelessWidget {
  const IptvFloatingEpg({
    super.key,
    required this.future,
    required this.maxWidth,
  });

  final Future<List<EpgEntry>> future;
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
        child: IptvGuideEpgCard(future: future, floating: true),
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
