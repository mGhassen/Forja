import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

/// Continue-watching card paint — props only (RFC-106 Zone A).
///
/// Host wraps with focus / TV actions when needed.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.width,
    required this.height,
    this.subtitle = '',
    this.progress = 0,
    this.remainingText = '',
    this.isLoading = false,
    this.active = false,
    this.borderRadius = 14,
    this.showActionButtons = true,
    this.onTap,
    this.onRemove,
    this.onInfo,
    this.playOverlay,
  });

  final String title;
  final String coverUrl;
  final String subtitle;
  final double progress;
  final String remainingText;
  final double width;
  final double height;
  final bool isLoading;
  final bool active;
  final double borderRadius;
  final bool showActionButtons;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onInfo;

  /// Optional play glyph overlay (host shell).
  final Widget? playOverlay;

  static const double hoverScale = 1.06;

  @override
  Widget build(BuildContext context) {
    final cover = resolveAbsoluteCoverUrl(coverUrl);
    final card = AnimatedScale(
      scale: active ? hoverScale : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: active
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFF0A0A0A),
                child: cover.isNotEmpty
                    ? ForjaNetworkImage(
                        url: cover,
                        fit: BoxFit.cover,
                        placeholder: const ColoredBox(color: Color(0xFF0A0A0A)),
                      )
                    : const Icon(Icons.movie, color: Colors.white24, size: 40),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
              if (showActionButtons)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Column(
                    children: [
                      if (onRemove != null)
                        Button(
                          variant: ButtonVariant.plainIcon,
                          size: ButtonSize.icon,
                          icon: Icons.close_rounded,
                          iconSize: 14,
                          height: 28,
                          color: Colors.white70,
                          onPressed: onRemove,
                        ),
                      if (onInfo != null) ...[
                        const SizedBox(height: 4),
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onInfo,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          if (remainingText.isNotEmpty)
                            Text(
                              remainingText,
                              style: TextStyle(
                                color: ForjaShellColors.badgeLabel,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: ForjaShellColors.sectionAccent,
                      minHeight: 3,
                    ),
                  ],
                ),
              ),
              if (playOverlay != null) playOverlay!,
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ForjaShellColors.sectionAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null || isLoading) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
