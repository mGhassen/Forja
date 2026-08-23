import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flat shell chip fill + border - matches sources panel / home filter style.
BoxDecoration shellChipDecoration({
  required bool selected,
  bool accentHover = false,
  double radius = 20,
}) {
  final Color fill;
  final Color border;
  if (accentHover) {
    // Tinted green, not solid brand fill. Wins over selected.
    fill = ForjaShellColors.brandGreen.withValues(alpha: 0.14);
    border = ForjaShellColors.brandGreen.withValues(alpha: 0.5);
  } else if (selected) {
    fill = ForjaShellColors.chipSelectedBg;
    border = ForjaShellColors.chipSelectedBorder;
  } else {
    fill = Colors.white.withValues(alpha: 0.07);
    border = ForjaShellColors.cinematic.borderSubtle;
  }
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );
}

/// Clipped Material + InkWell - hover/splash follow [radius] (pills, list rows).
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
  final highlightColor =
      suppressInkHover ? Colors.transparent : null;
  final focusColor = suppressInkHover ? Colors.transparent : null;
  final borderRadius = BorderRadius.circular(radius);
  Widget body = child;
  if (padding != null) {
    body = Padding(padding: padding, child: body);
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
              highlightColor: highlightColor,
              focusColor: focusColor,
              child: body,
            ),
          )
        : InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            hoverColor: hoverColor,
            splashColor: splashColor,
            highlightColor: highlightColor,
            focusColor: focusColor,
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

/// Selectable pill chip for filters, moods, modes - no theme purple borders.
class ForjaShellChip extends StatefulWidget {
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
    this.focusNode,
    this.listIndex,
    this.tvTabId,
    this.tvRowId,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.accentHover = false,
    this.loading = false,
    this.onCancel,
    this.onReload,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final FocusNode? focusNode;
  final int? listIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  /// Desktop hover: tinted brand-green chrome instead of solid white ink.
  final bool accentHover;

  /// Same cycling `...` as Sources kind tabs while this chip is checking.
  final bool loading;

  /// Hover loading → ✕; tap cancels this chip's fetch (kind-tab parity).
  final VoidCallback? onCancel;

  /// Idle selected chip: refresh icon re-runs this chip only.
  final VoidCallback? onReload;

  @override
  State<ForjaShellChip> createState() => _ForjaShellChipState();
}

class _ForjaShellChipState extends State<ForjaShellChip> {
  bool _hovered = false;
  bool _focused = false;
  bool _busyHovered = false;
  bool _reloadHovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final policy = ShellScope.inputPolicyOf(context);
    final tv = policy.useFocusableMoodChips;
    final focusStyled = policy.focusStyled(context, focused: _focused);
    final accent = widget.accentHover && (_hovered || focusStyled);
    // Desktop: reload only on chip hover. Touch/TV: always (no hover).
    final showReload = widget.onReload != null &&
        (!policy.scaleOnHover || _hovered || focusStyled);
    final cinematic = ForjaShellColors.cinematic;
    final fg = accent
        ? ForjaShellColors.brandGreen
        : selected
            ? cinematic.textPrimary
            : cinematic.textSecondary;
    final borderRadius = BorderRadius.circular(widget.radius);

    final face = AnimatedContainer(
      duration: tv ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: shellChipDecoration(
        selected: selected,
        accentHover: accent,
        radius: widget.radius,
      ),
      padding: widget.padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              color: fg,
              fontSize: widget.fontSize,
              fontWeight: selected || accent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (widget.loading) ...[
            const SizedBox(width: 4),
            ForjaBusyCancelGlyph(
              color: fg,
              hovered: _busyHovered,
              onHover: (v) => setState(() => _busyHovered = v),
              onCancel: widget.onCancel,
            ),
          ] else if (showReload) ...[
            const SizedBox(width: 6),
            ExcludeFocus(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _reloadHovered = true),
                onExit: (_) => setState(() => _reloadHovered = false),
                child: GestureDetector(
                  onTap: widget.onReload,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedRotation(
                    turns: _reloadHovered ? 0.5 : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
          ] else if (widget.trailing != null) ...[
            const SizedBox(width: 4),
            widget.trailing!,
          ],
        ],
      ),
    );

    Widget body;
    if (tv) {
      body = shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        focusNode: widget.focusNode,
        borderRadius: widget.radius,
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        listIndex: widget.listIndex,
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.listIndex,
        tvZone: ShellTvZone.chipStrip,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: widget.accentHover || widget.onReload != null
            ? (focused) => setState(() => _focused = focused)
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: face,
        ),
      );
    } else {
      body = shellRoundedInkHost(
        radius: widget.radius,
        onTap: widget.onTap,
        suppressInkHover: widget.accentHover,
        child: face,
      );
    }

    final trackHover =
        !tv && (widget.accentHover || widget.onReload != null);
    if (!trackHover) return body;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _busyHovered = false;
        _reloadHovered = false;
      }),
      child: body,
    );
  }
}
