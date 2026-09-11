import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Shell top bar — leading / title / actions slots, or a custom [child] column
/// (pack `kit.menu` + `kit.tabs`). Replaces [TopBarSlots].
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.leading,
    this.title,
    this.titleWidget,
    this.actions,
    this.child,
    this.height = 56,
    this.padding,
  });

  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;

  /// When set, replaces the default leading/title/actions row.
  final Widget? child;
  final double height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return SizedBox(
        height: height,
        child: child,
      );
    }

    final theme = ForjaThemeExtension.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: padding ??
            EdgeInsets.symmetric(horizontal: theme.spaceMd),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              SizedBox(width: theme.spaceSm),
            ],
            Expanded(
              child: titleWidget ??
                  (title != null
                      ? Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox.shrink()),
            ),
            if (actions != null) ...[
              SizedBox(width: theme.spaceSm),
              for (var i = 0; i < actions!.length; i++) ...[
                if (i > 0) SizedBox(width: theme.spaceSm),
                actions![i],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// @deprecated Use [TopBar].
typedef TopBarSlots = TopBar;
