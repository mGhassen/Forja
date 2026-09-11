import 'package:flutter/material.dart' hide ListTile;
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Density for [ListTile].
enum ListTileDensity {
  dense,
  default_,
}

/// Forja list row — leading / title / subtitle / trailing.
class ListTile extends StatelessWidget {
  const ListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.density = ListTileDensity.default_,
    this.focusNode,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final ListTileDensity density;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final dense = density == ListTileDensity.dense;
    final padV = dense ? 8.0 : 12.0;
    final titleSize = dense ? 13.0 : 14.0;
    final subSize = dense ? 11.0 : 12.0;

    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        focusNode: focusNode,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spaceMd,
            vertical: padV,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: theme.textSecondary,
                    size: dense ? 20 : 22,
                  ),
                  child: leading!,
                ),
                SizedBox(width: theme.spaceMd),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      DefaultTextStyle(
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                        ),
                        child: title!,
                      ),
                    if (subtitle != null) ...[
                      SizedBox(height: dense ? 2 : 4),
                      DefaultTextStyle(
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: subSize,
                          fontWeight: FontWeight.w400,
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: theme.spaceSm),
                IconTheme(
                  data: IconThemeData(
                    color: theme.textSecondary,
                    size: dense ? 18 : 20,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
