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
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<ForjaActionChip> createState() => _ForjaActionChipState();
}

class _ForjaActionChipState extends State<ForjaActionChip> {
  bool _focused = false;
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  bool _activeFor(bool hovered) => ShellPaintScope.interactiveActive(
        context,
        hovered: hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    final height =
        tvDensity ? ShellTokens.actionChipHeightTv : widget.height;
    final fontSize =
        tvDensity ? ShellTokens.actionChipFontSizeTv : widget.fontSize;
    final iconSize = tvDensity
        ? (widget.iconSize ?? ShellTokens.actionChipIconSizeTv)
        : (widget.iconSize ?? (widget.iconOnly ? 20 : 14));
    final padding = tvDensity
        ? EdgeInsets.symmetric(
            horizontal: ShellTokens.actionChipPadHTv,
            vertical: ShellTokens.actionChipPadV,
          )
        : widget.padding;
    final tvFocused = ShellPaintScope.focusStyledOf(context, focused: _focused);

    if (widget.iconOnly) {
      final size = height;
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: size / 2,
        motion: ForjaMotionPreset.fillOnly,
        suppressInkHover: true,
        showFocusFill: false,
        listIndex: widget.tvItemIndex,
        tvItemIndex: widget.tvItemIndex,
        tvZone: ShellPaintTvZone.topBar,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onDownEdge: widget.onDownEdge,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final active =
                _activeFor(_hoveredN.value) || widget.selected;
            final lit = active || tvFocused;
            // Hover / focus / selected — brand green chrome (same as pill chips).
            final fg = lit ? ForjaShellColors.brandGreen : Colors.white70;
            final idleAlpha = widget.selected ? 0.12 : 0.08;
            final circle = Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: lit
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: idleAlpha),
                shape: BoxShape.circle,
                border: Border.all(
                  color: tvFocused
                      ? ForjaShellColors.brandGreen
                      : active || widget.selected
                          ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.12),
                  width: tvFocused ? 1.5 : 1,
                ),
              ),
              child: Icon(
                widget.icon ?? Icons.refresh_rounded,
                color: fg,
                size: iconSize,
              ),
            );
            return Tooltip(
              message: widget.label.isEmpty ? 'Refresh' : widget.label,
              child: circle,
            );
          },
        ),
      );
    }

    Widget buildChip(bool hovered) {
      final active = _activeFor(hovered) || widget.selected;
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

      return AnimatedContainer(
        duration: ForjaMotionTheme.of(context).fillOnly.duration,
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: border, width: tvFocused ? 1.5 : 1),
        ),
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: iconSize, color: fg),
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
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (!_tv) {
      return MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: shellRoundedInkHost(
          radius: widget.radius,
          onTap: widget.onTap,
          child: ListenableBuilder(
            listenable: _hoveredN,
            builder: (context, _) => buildChip(_hoveredN.value),
          ),
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
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellPaintTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: _setHovered,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => buildChip(_hoveredN.value),
      ),
    );
  }
}
