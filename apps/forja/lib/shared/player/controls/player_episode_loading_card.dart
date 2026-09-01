import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/torrent_loading_status_panel.dart';
import 'package:rust/rust.dart';

/// Compact floating card shown while the player resolves another episode.
///
/// Sits bottom-right above the seek bar (like the Skip / Next Episode chips) -
/// flat translucent shell surface, no border, no full-screen scrim so live
/// video stays visible behind it (and no [BackdropFilter] over video on macOS).
class PlayerEpisodeLoadingCard extends StatelessWidget {
  const PlayerEpisodeLoadingCard({
    super.key,
    required this.episodeLabel,
    required this.status,
    this.torrentStatus,
    this.failed = false,
  });

  final String episodeLabel;
  final String status;
  final TorrentLoadingStatus? torrentStatus;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final accent = failed
        ? const Color(0xFFF87171)
        : ForjaShellColors.sectionAccent;

    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: failed
                      ? Icon(
                          Icons.error_outline_rounded,
                          color: accent,
                          size: 22,
                        )
                      : CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: accent,
                        ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (torrentStatus != null && !failed) ...[
                        TorrentLoadingStatusCompact(status: torrentStatus!),
                      ] else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Text(
                            status,
                            key: ValueKey(status),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: failed
                                  ? accent.withValues(alpha: 0.95)
                                  : ForjaShellColors.cinematic.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
