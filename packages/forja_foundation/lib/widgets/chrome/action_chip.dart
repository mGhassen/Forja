import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Kit primitive — badge / chip action (pack-declared top-bar filters, etc.).
///
/// No product names. Packs supply [label] / [icon]; host paints IPTV-style chip.
class ForjaActionChip extends StatefulWidget {
  const ForjaActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.iconOnly = false,
    this.height = ShellTokens.actionChipHeight,
    this.radius = ShellTokens.actionChipRadius,
    this.maxWidth = ShellTokens.actionChipMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: ShellTokens.actionChipPadH, vertical: ShellTokens.actionChipPadV),
    this.fontSize = ShellTokens.actionChipFontSize,
    this.iconSize,
    this.gap = ShellTokens.actionChipGap,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool selected;
  /// Icon-only control (e.g. Live Sports Refresh).
  final bool iconOnly;

  /// Icon-only circle size.
  final double height;
  final double radius;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  /// Label chip icon (default 14) / iconOnly (default 20).
  final double? iconSize;
  final double gap;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<ForjaActionChip> createState() => _ForjaActionChipState();
}

class _ForjaActionChipState extends State<ForjaActionChip> {
  bool _focused = false;
  bool _hovered = false;

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  bool get _active => ShellPaintScope.interactiveActive(
        context,
        hovered: _hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final active = _active || widget.selected;
    final tvFocused = ShellPaintScope.focusStyledOf(context, focused: _focused);

    if (widget.iconOnly) {
      final size = widget.height;
      final fg = active || tvFocused ? Colors.white : Colors.white70;
      final idleAlpha = widget.selected ? 0.12 : 0.08;
      final circle = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: active || tvFocused ? 0.16 : idleAlpha,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(
              alpha: tvFocused
                  ? 0.45
                  : active || widget.selected
                      ? 0.28
                      : 0.12,
            ),
            width: tvFocused ? 1.5 : 1,
          ),
        ),
        child: Icon(
          widget.icon ?? Icons.refresh_rounded,
          color: fg,
          size: widget.iconSize ?? 20,
        ),
      );
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: size / 2,
        motion: ForjaMotionPreset.fillOnly,
        suppressInkHover: true,
        showFocusFill: false,
        listIndex: widget.tvItemIndex,
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.tvItemIndex,
        tvZone: ShellPaintTvZone.topBar,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onDownEdge: widget.onDownEdge,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) => setState(() => _hovered = h),
        child: Tooltip(
          message: widget.label.isEmpty ? 'Refresh' : widget.label,
          child: circle,
        ),
      );
    }

    final bg = active
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.06);
    final border = tvFocused
        ? ForjaShellColors.brandGreen
        : active
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
            : ForjaShellColors.borderSubtle.withValues(alpha: 0.55);
    final fg = tvFocused || active
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.cinematic.textSecondary;

    // Cap width — Catalog can fall back to a long id (e.g. stremio:<url>).
    final chip = AnimatedContainer(
      duration: ForjaMotionTheme.of(context).fillOnly.duration,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border, width: tvFocused ? 1.5 : 1),
      ),
      padding: widget.padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: widget.iconSize ?? 14, color: fg),
            if (widget.label.isNotEmpty) SizedBox(width: widget.gap),
          ],
          if (widget.label.isNotEmpty)
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    if (!_tv) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: shellRoundedInkHost(
          radius: widget.radius,
          onTap: widget.onTap,
          child: chip,
        ),
      );
    }

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: widget.radius,
      motion: ForjaMotionPreset.fillOnly,
      suppressInkHover: true,
      showFocusFill: false,
      listIndex: widget.tvItemIndex,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellPaintTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: chip,
    );
  }
}
