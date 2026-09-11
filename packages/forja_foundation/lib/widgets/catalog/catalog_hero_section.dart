import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Catalog home hero — props + slots only (RFC-106 G5).
///
/// Dual hero stack with [CinematicHero]: this is the title/actions overlay;
/// [CinematicHero] is the full-bleed cinematic frame.
class CatalogHeroSection extends StatelessWidget {
  const CatalogHeroSection({
    super.key,
    required this.title,
    this.backdropUrl,
    this.logoUrl,
    this.subtitle,
    this.actions,
    this.onPlay,
    this.height = 360,
  });

  final String title;
  final String? backdropUrl;
  final String? logoUrl;
  final String? subtitle;
  final Widget? actions;
  final VoidCallback? onPlay;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final backdrop = backdropUrl?.trim() ?? '';
    final logo = logoUrl?.trim() ?? '';

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop.isNotEmpty)
            Image.network(
              backdrop,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: theme.bgDark),
            )
          else
            ColoredBox(color: theme.bgDark),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xCC000000),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: theme.spaceLg,
            right: theme.spaceLg,
            bottom: theme.spaceLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logo.isNotEmpty)
                  Image.network(
                    logo,
                    height: 56,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _titleText(),
                  )
                else
                  _titleText(),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  SizedBox(height: theme.spaceSm),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
                SizedBox(height: theme.spaceMd),
                actions ??
                    (onPlay != null
                        ? Button(
                            variant: ButtonVariant.primary,
                            label: 'Play',
                            icon: Icons.play_arrow,
                            onPressed: onPlay,
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleText() {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: ForjaShellColors.cinematic.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
