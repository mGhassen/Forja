import 'package:flutter/material.dart';
import 'package:rust/rust.dart';

/// Compact transparent torrent stats chip for the desktop player overlay.
class PlayerTorrentStatsCard extends StatelessWidget {
  const PlayerTorrentStatsCard({
    super.key,
    required this.stats,
    this.indexerSeeders,
  });

  final TorrentStats stats;
  final int? indexerSeeders;

  @override
  Widget build(BuildContext context) {
    final seederText = indexerSeeders != null ? '$indexerSeeders' : '—';
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(Icons.download_rounded, stats.speedLabel),
                const SizedBox(height: 3),
                _row(Icons.upload_rounded, stats.uploadLabel),
                const SizedBox(height: 3),
                _row(Icons.people_outline_rounded,
                    '${stats.activePeers} live · ${stats.totalPeers} seen'),
                const SizedBox(height: 3),
                _row(Icons.eco_outlined, '$seederText seeders'),
                const SizedBox(height: 3),
                _row(Icons.storage_outlined, '${stats.sizeLabel} · ${stats.cacheLabel}'),
                const SizedBox(height: 3),
                _row(Icons.timer_outlined, 'ETA ${stats.etaLabel}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
