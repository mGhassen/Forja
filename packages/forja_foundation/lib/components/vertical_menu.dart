import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

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
    this.clipBehavior = Clip.antiAlias,
    this.minHeight = 40,
    this.fontSize = 14,
    this.leadingSize = 28,
  });

  final List<Widget> children;
  final double width;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  /// Host rails that hover-scale tiles need [Clip.none] so scale can paint into pad.
  final Clip clipBehavior;
  final double minHeight;
  final double fontSize;
  final double leadingSize;

  /// One selectable row in a [VerticalMenu].
  static Widget item({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    Widget? leading,
    bool selected = false,
    bool accentHover = false,
    FocusNode? focusNode,
  }) {
    return _VerticalMenuItem(
      key: key,
      label: label,
      onTap: onTap,
      leading: leading,
      selected: selected,
      accentHover: accentHover,
      focusNode: focusNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return _VerticalMenuStyle(
      minHeight: minHeight,
      fontSize: fontSize,
      leadingSize: leadingSize,
      child: Material(
        color: backgroundColor ?? ForjaShellColors.bgDark,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        clipBehavior: clipBehavior,
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
      ),
    );
  }
}

class _VerticalMenuStyle extends InheritedWidget {
  const _VerticalMenuStyle({
    required this.minHeight,
    required this.fontSize,
    required this.leadingSize,
    required super.child,
  });

  final double minHeight;
  final double fontSize;
  final double leadingSize;

  static _VerticalMenuStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_VerticalMenuStyle>();

  @override
  bool updateShouldNotify(covariant _VerticalMenuStyle oldWidget) =>
      minHeight != oldWidget.minHeight ||
      fontSize != oldWidget.fontSize ||
      leadingSize != oldWidget.leadingSize;
}

class _VerticalMenuItem extends StatefulWidget {
  const _VerticalMenuItem({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.selected = false,
    this.accentHover = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool selected;
  final bool accentHover;
  final FocusNode? focusNode;

  @override
  State<_VerticalMenuItem> createState() => _VerticalMenuItemState();
}

class _VerticalMenuItemState extends State<_VerticalMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final style = _VerticalMenuStyle.maybeOf(context);
    final minHeight = style?.minHeight ?? 40;
    final fontSize = style?.fontSize ?? 14;
    final leadingSize = style?.leadingSize ?? 28;
    final lit = widget.selected || (widget.accentHover && _hovered);
    final fg = lit ? theme.textPrimary : theme.textSecondary;
    final fill = widget.selected
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.18)
        : (_hovered && widget.accentHover)
            ? ForjaShellColors.inkHover
            : Colors.transparent;

    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          left: BorderSide(
            color: widget.selected
                ? ForjaShellColors.brandGreen
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: theme.spaceMd,
          vertical: theme.spaceSm,
        ),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              SizedBox(
                width: leadingSize,
                height: leadingSize,
                child: widget.leading,
              ),
              SizedBox(width: theme.spaceSm),
            ],
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: lit ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Focus(focusNode: widget.focusNode, child: row),
      ),
    );
  }
}
