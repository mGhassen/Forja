import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';

/// Readable torrent resolve status for [LoadingOverlay] — headline + stat tiles.
class TorrentLoadingStatusPanel extends StatelessWidget {
  const TorrentLoadingStatusPanel({super.key, required this.status});

  final TorrentLoadingStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0.15,
            fontFamily: 'Poppins',
          ),
        ),
        if (status.hint != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              status.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
                letterSpacing: 0.1,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
        if (status.hasStats) ...[
          const SizedBox(height: 22),
          _StatsCard(status: status),
        ],
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.status});

  final TorrentLoadingStatus status;

  @override
  Widget build(BuildContext context) {
    final peers = status.activePeers;
    final seen = status.totalPeers;
    final peerValue = peers != null ? '$peers' : '—';
    final peerLabel = seen != null && seen > 0
        ? peers != null && peers > 0 && seen > peers
            ? 'of $seen peers'
            : seen > 0 && (peers ?? 0) == 0
                ? '$seen seen'
                : 'peers'
        : 'peers';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_outline_rounded,
                  value: peerValue,
                  label: peerLabel,
                ),
              ),
              _divider(),
              Expanded(
                child: _StatTile(
                  icon: Icons.download_rounded,
                  value: status.speedLabel ?? '—',
                  label: 'Download',
                  accent: status.speedLabel != null,
                ),
              ),
              _divider(),
              Expanded(
                child: _StatTile(
                  icon: status.hasHeadProgress
                      ? Icons.play_circle_outline_rounded
                      : Icons.storage_rounded,
                  value: status.hasHeadProgress
                      ? (status.headProgressLabel ?? '…')
                      : (status.bufferLabel ?? '…'),
                  label: status.hasHeadProgress ? 'To start' : 'File cached',
                  accent: status.hasHeadProgress
                      ? status.headProgressFraction > 0
                      : status.bufferLabel != null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final valueColor = accent
        ? AppTheme.primaryColor
        : Colors.white.withValues(alpha: 0.9);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: 0.1,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0.2,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
