import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    this.titleFontSize,
    this.subtitleFontSize,
    this.remainingFontSize,
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
  final double? titleFontSize;
  final double? subtitleFontSize;
  final double? remainingFontSize;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onInfo;

  /// Optional play glyph overlay (host shell).
  final Widget? playOverlay;

  @override
  Widget build(BuildContext context) {
    final cover = resolveAbsoluteCoverUrl(coverUrl);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleFontSize =
        this.titleFontSize ?? (tv ? ShellTokens.tvBodyFontSize : 13.0);
    final subtitleFontSize =
        this.subtitleFontSize ?? (tv ? ShellTokens.tvMetaFontSize : 12.0);
    final remainingFontSize =
        this.remainingFontSize ?? (tv ? ShellTokens.tvMetaFontSize : 11.0);
    final card = ForjaMotionScale(
      preset: ForjaMotionPreset.cardLift,
      active: active,
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
                    : Icon(
                        Icons.movie,
                        color: Colors.white24,
                        size: ShellPaintScope.iconOf(context, 40),
                      ),
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
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white70,
                                size: ShellPaintScope.iconOf(context, 14),
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
                          CrossfadeSwap(
                            child: Text(
                              title,
                              key: ValueKey(title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: titleFontSize,
                              ),
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            CrossfadeSwap(
                              child: Text(
                                subtitle,
                                key: ValueKey(subtitle),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: subtitleFontSize,
                                ),
                              ),
                            ),
                          if (remainingText.isNotEmpty)
                            CrossfadeSwap(
                              child: Text(
                                remainingText,
                                key: ValueKey(remainingText),
                                style: TextStyle(
                                  color: ForjaShellColors.badgeLabel,
                                  fontSize: remainingFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
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
              if (playOverlay != null) Center(child: playOverlay),
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
