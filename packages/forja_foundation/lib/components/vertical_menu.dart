import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Vertical selectable flyout menu (Home platforms, etc.).
///
/// Items via [VerticalMenu.item] / children — not a peer VerticalMenuItem product.
class VerticalMenu extends StatelessWidget {
  const VerticalMenu({
    super.key,
    required this.children,
    this.width = 220,
    this.padding,
    this.backgroundColor,
  });

  final List<Widget> children;
  final double width;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  /// One selectable row in a [VerticalMenu].
  static Widget item({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    Widget? leading,
    bool selected = false,
    FocusNode? focusNode,
  }) {
    return _VerticalMenuItem(
      key: key,
      label: label,
      onTap: onTap,
      leading: leading,
      selected: selected,
      focusNode: focusNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Material(
      color: backgroundColor ?? const Color(0xFF141414),
      borderRadius: BorderRadius.circular(theme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(vertical: theme.spaceSm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _VerticalMenuItem extends StatelessWidget {
  const _VerticalMenuItem({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.selected = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool selected;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final fg = selected ? theme.textPrimary : theme.textSecondary;
    return InkWell(
      onTap: onTap,
      focusNode: focusNode,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: EdgeInsets.symmetric(
          horizontal: theme.spaceMd,
          vertical: theme.spaceSm,
        ),
        color: selected ? Colors.white.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 28, height: 28, child: leading),
              SizedBox(width: theme.spaceSm),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
