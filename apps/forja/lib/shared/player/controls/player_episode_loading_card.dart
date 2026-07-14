import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Centered translucent card shown while the player resolves another episode.
///
/// Uses the player-safe frosted tint ([ForjaFrostedPanel] without
/// [BackdropFilter] over live video) so macOS textures stay intact.
class PlayerEpisodeLoadingCard extends StatelessWidget {
  const PlayerEpisodeLoadingCard({
    super.key,
    required this.episodeLabel,
    required this.status,
    this.failed = false,
  });

  final String episodeLabel;
  final String status;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final accent = failed
        ? const Color(0xFFF87171)
        : ForjaShellColors.sectionAccent;

    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: failed ? 0.22 : 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: failed
                      ? Icon(
                          Icons.error_outline_rounded,
                          color: accent,
                          size: 34,
                        )
                      : CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: accent,
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  episodeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Text(
                    status,
                    key: ValueKey(status),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: failed
                          ? accent.withValues(alpha: 0.95)
                          : ForjaShellColors.cinematic.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      fontFamily: 'Poppins',
                    ),
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
