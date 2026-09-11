import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Full-bleed cinematic hero frame — props + child slots only (RFC-106 G5).
///
/// Pair with [CatalogHeroSection] for the dual-hero stack (see convergences).
class CinematicHero extends StatelessWidget {
  const CinematicHero({
    super.key,
    this.backdropUrl,
    this.logoUrl,
    this.title,
    this.child,
    this.overlay,
    this.height = 420,
    this.alignment = Alignment.centerRight,
  });

  final String? backdropUrl;
  final String? logoUrl;
  final String? title;
  final Widget? child;
  final Widget? overlay;
  final double height;
  final Alignment alignment;

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
              alignment: alignment,
              errorBuilder: (_, _, _) => ColoredBox(color: theme.bgDark),
            )
          else
            ColoredBox(color: theme.bgDark),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE6000000),
                  Color(0x66000000),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          if (overlay != null) overlay!,
          if (child != null)
            child!
          else
            Positioned(
              left: theme.spaceLg,
              bottom: theme.spaceLg,
              right: theme.spaceLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logo.isNotEmpty)
                    Image.network(
                      logo,
                      height: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _fallbackTitle(),
                    )
                  else if (title != null && title!.trim().isNotEmpty)
                    _fallbackTitle(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackTitle() {
    if (title == null || title!.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      title!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: ForjaShellColors.cinematic.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
