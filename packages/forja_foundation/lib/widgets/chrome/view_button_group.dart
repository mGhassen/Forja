import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// One icon slot in a [ViewButtonGroup].
class ViewButtonItem {
  const ViewButtonItem({
    required this.id,
    required this.icon,
    this.label = '',
  });

  final String id;
  final IconData icon;
  final String label;
}

/// Compact icon toggle group (cards / list / timeline) — old IPTV view chrome.
class ViewButtonGroup extends StatelessWidget {
  const ViewButtonGroup({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.height = ShellTokens.viewButtonHeight,
    this.iconSize = ShellTokens.viewButtonIconSize,
    this.dividerHeight = ShellTokens.viewButtonGap,
  });

  final List<ViewButtonItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final double height;
  final double iconSize;
  final double dividerHeight;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final r = Radius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: dividerHeight,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            _ViewButtonSlot(
              item: items[i],
              selected: selectedId == items[i].id,
              isFirst: i == 0,
              isLast: i == items.length - 1,
              height: height,
              radius: r,
              iconSize: iconSize,
              listIndex: i,
              onTap: () => onSelect(items[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewButtonSlot extends StatefulWidget {
  const _ViewButtonSlot({
    required this.item,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.height,
    required this.radius,
    required this.iconSize,
    required this.listIndex,
    required this.onTap,
  });

  final ViewButtonItem item;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final double height;
  final Radius radius;
  final double iconSize;
  final int listIndex;
  final VoidCallback onTap;

  @override
  State<_ViewButtonSlot> createState() => _ViewButtonSlotState();
}

class _ViewButtonSlotState extends State<_ViewButtonSlot> {
  bool _hovered = false;
  bool _focused = false;

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  bool get _active =>
      widget.selected ||
      ShellPaintScope.interactiveActive(
        context,
        hovered: _hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final slot = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: widget.height,
      height: widget.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _active
            ? Colors.white.withValues(
                alpha: ShellPaintScope.interactiveActive(
                  context,
                  hovered: _hovered,
                  focused: _focused,
                )
                    ? 0.16
                    : 0.10,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.horizontal(
          left: widget.isFirst ? widget.radius : Radius.zero,
          right: widget.isLast ? widget.radius : Radius.zero,
        ),
      ),
      child: Icon(
        widget.item.icon,
        size: widget.iconSize,
        color: widget.selected ? Colors.white : Colors.white60,
      ),
    );

    final child = widget.item.label.isEmpty
        ? slot
        : Tooltip(message: widget.item.label, child: slot);

    if (!_tv) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: shellRoundedInkHost(
          radius: widget.height / 2,
          onTap: widget.onTap,
          suppressInkHover: true,
          child: child,
        ),
      );
    }

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: widget.height / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      listIndex: widget.listIndex,
      tvRowId: 'view-button-group',
      tvItemIndex: widget.listIndex,
      tvZone: ShellPaintTvZone.topBar,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: child,
    );
  }
}
