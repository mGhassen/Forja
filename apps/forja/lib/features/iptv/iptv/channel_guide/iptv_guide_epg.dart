import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';

import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';

/// Memoized short-EPG fetches for the in-player channel guide.
class IptvGuideEpgCache {
  IptvGuideEpgCache(this.portal);

  final VerifiedPortal portal;
  final Map<String, Future<List<EpgEntry>>> _cache = {};

  Future<List<EpgEntry>> load(String streamId, {int limit = 6}) {
    if (streamId.isEmpty) return Future.value(const []);
    final key = '$streamId:$limit';
    return _cache.putIfAbsent(
      key,
      () => IptvClient.shortEpg(portal.portal, streamId, limit: limit),
    );
  }

  void clear() => _cache.clear();
}

/// Stable height for the full EPG card in the channel-guide header.
const double kIptvGuideEpgCardHeight = 132;

class IptvGuideEpgCard extends StatefulWidget {
  const IptvGuideEpgCard({
    super.key,
    required this.future,
    this.compact = false,
  });

  final Future<List<EpgEntry>> future;
  final bool compact;

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

  Widget _fullCardShell({required Widget child}) {
    return SizedBox(
      height: kIptvGuideEpgCardHeight,
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
          style: GoogleFonts.poppins(
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

        if (widget.compact) {
          return _CompactEpgRow(entry: nowEntry, isLive: nowEntry.isNow);
        }

        return _fullCardShell(
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
                style: GoogleFonts.poppins(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.small = false,
  });

  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 6,
        vertical: small ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: small ? 0.35 : 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: small ? 8 : 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
