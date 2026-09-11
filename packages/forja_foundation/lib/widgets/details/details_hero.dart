import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Details page hero frame — props + slots only (RFC-106 G5).
class DetailsHero extends StatelessWidget {
  const DetailsHero({
    super.key,
    required this.title,
    this.backdropUrl,
    this.posterUrl,
    this.logoUrl,
    this.subtitle,
    this.meta,
    this.actions,
    this.height = 320,
  });

  final String title;
  final String? backdropUrl;
  final String? posterUrl;
  final String? logoUrl;
  final String? subtitle;
  final Widget? meta;
  final Widget? actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final backdrop = backdropUrl?.trim() ?? '';
    final poster = posterUrl?.trim() ?? '';
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
                end: Alignment.center,
                colors: [Color(0xE6000000), Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            left: theme.spaceLg,
            right: theme.spaceLg,
            bottom: theme.spaceLg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (poster.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    child: Image.network(
                      poster,
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(width: theme.spaceMd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (logo.isNotEmpty)
                        Image.network(
                          logo,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _title(),
                        )
                      else
                        _title(),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        SizedBox(height: theme.spaceSm),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.cinematic.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (meta != null) ...[
                        SizedBox(height: theme.spaceSm),
                        meta!,
                      ],
                      if (actions != null) ...[
                        SizedBox(height: theme.spaceMd),
                        actions!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title() {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: ForjaShellColors.cinematic.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
