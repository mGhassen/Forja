import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/chrome/shell_focusable_tap.dart';

/// Kit primitive — badge / chip action (pack-declared top-bar filters, etc.).
///
/// No product names. Packs supply [label] / [icon]; host paints IPTV-style chip.
class CatalogKitActionChip extends StatefulWidget {
  const CatalogKitActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
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
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<CatalogKitActionChip> createState() => _CatalogKitActionChipState();
}

class _CatalogKitActionChipState extends State<CatalogKitActionChip> {
  static const _radius = 20.0;
  bool _focused = false;
  bool _hovered = false;

  bool get _tv => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  bool get _active {
    final policy = ShellScope.inputPolicyOf(context);
    return ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _active || widget.selected;
    final tvFocused = _tv && _focused;
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

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: border, width: tvFocused ? 1.5 : 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
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
          radius: _radius,
          onTap: widget.onTap,
          child: chip,
        ),
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: _radius,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      listIndex: widget.tvItemIndex,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: chip,
    );
  }
}
