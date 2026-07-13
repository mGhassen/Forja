import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flat shell chip fill + border — matches sources panel / home filter style.
BoxDecoration shellChipDecoration({
  required bool selected,
  double radius = 20,
}) {
  return BoxDecoration(
    color: selected
        ? ForjaShellColors.chipSelectedBg
        : Colors.white.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected
          ? ForjaShellColors.chipSelectedBorder
          : ForjaShellColors.cinematic.borderSubtle,
    ),
  );
}

/// Clipped Material + InkWell — hover/splash follow [radius] (pills, list rows).
Widget shellRoundedInkHost({
  required Widget child,
  required double radius,
  VoidCallback? onTap,
  Color? backgroundColor,
  BoxDecoration? decoration,
  EdgeInsetsGeometry? padding,
  bool suppressInkHover = false,
}) {
  final hoverColor =
      suppressInkHover ? Colors.transparent : ForjaShellColors.inkHover;
  final splashColor =
      suppressInkHover ? Colors.transparent : ForjaShellColors.inkSplash;
  final borderRadius = BorderRadius.circular(radius);
  Widget body = child;
  if (padding != null) {
    body = Padding(padding: padding, child: child);
  }

  if (onTap == null && decoration == null && backgroundColor == null) {
    return body;
  }

  if (onTap == null) {
    return Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: decoration != null
          ? Ink(decoration: decoration, child: body)
          : body,
    );
  }

  return Material(
    color: backgroundColor ?? Colors.transparent,
    borderRadius: borderRadius,
    clipBehavior: Clip.antiAlias,
    child: decoration != null
        ? Ink(
            decoration: decoration,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              hoverColor: hoverColor,
              splashColor: splashColor,
              child: body,
            ),
          )
        : InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            hoverColor: hoverColor,
            splashColor: splashColor,
            child: body,
          ),
  );
}

/// Rounded hover/focus overlay for [MenuItemButton] and compact list rows.
ButtonStyle shellMenuItemStyle({
  double radius = 8,
  EdgeInsetsGeometry padding =
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
}) {
  return ButtonStyle(
    padding: WidgetStatePropertyAll(padding),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return ForjaShellColors.inkHover;
      }
      return null;
    }),
  );
}

/// Selectable pill chip for filters, moods, modes — no theme purple borders.
class ForjaShellChip extends StatelessWidget {
  const ForjaShellChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.trailing,
    this.onTap,
    this.radius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.fontSize = 12.5,
    this.listIndex,
    this.tvTabId,
    this.tvRowId,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final int? listIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final fg = selected ? cinematic.textPrimary : cinematic.textSecondary;
    final borderRadius = BorderRadius.circular(radius);

    final chip = Ink(
      decoration: shellChipDecoration(selected: selected, radius: radius),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: fg,
                fontSize: fontSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return shellFocusableTap(
        context: context,
        onTap: onTap,
        borderRadius: radius,
        scaleOnFocus: 1.0,
        listIndex: listIndex,
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        tvItemIndex: listIndex,
        tvZone: ShellTvZone.chipStrip,
        onDownEdge: onDownEdge,
        onUpEdge: onUpEdge,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: chip,
        ),
      );
    }

    return shellRoundedInkHost(
      radius: radius,
      onTap: onTap,
      child: chip,
    );
  }
}
