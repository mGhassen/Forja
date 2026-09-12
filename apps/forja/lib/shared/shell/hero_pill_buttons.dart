import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/shell/forja_interactive.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';

export 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart'
    show HeroPillPlayTone, HeroMagnetIcon;

/// Primary hero CTA - pill with optional icon + label (Play, Watch Now, Resume).
class HeroPillPlayButton extends StatelessWidget {
  const HeroPillPlayButton({
    super.key,
    required this.label,
    this.icon = Icons.play_arrow_rounded,
    this.iconWidget,
    this.onTap,
    this.primary = true,
    this.tone,
    this.autoFocus = false,
    this.focusNode,
    this.alwaysShowLabel = false,
    this.onKeyEvent,
    this.tvTabId,
    this.onUpEdge,
    this.onRightEdge,
    this.tvRowId,
    this.tvItemIndex,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final bool primary;
  final HeroPillPlayTone? tone;
  final bool alwaysShowLabel;
  final bool autoFocus;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final String? tvTabId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final String? tvRowId;
  final int? tvItemIndex;

  HeroPillPlayTone get _tone =>
      tone ?? (primary ? HeroPillPlayTone.primary : HeroPillPlayTone.secondary);

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final style = HeroPillStyle.forTone(_tone);
    final leading = iconWidget ??
        (icon != null ? Icon(icon, size: kHeroPillIconSize) : null);
    final useTvCompact = policy.useFocusableMoodChips;
    final tvMeta = tvTabId != null && useTvCompact
        ? ShellTvFocusMeta(
            tabId: tvTabId!,
            zone: tvRowId != null && tvItemIndex != null
                ? ShellTvZone.row
                : ShellTvZone.hero,
            rowId: tvRowId,
            itemIndex: tvItemIndex,
          )
        : null;
    final effectiveOnKey = onUpEdge != null ||
            onRightEdge != null ||
            onKeyEvent != null
        ? (FocusNode node, KeyEvent event) {
            if (onUpEdge != null) {
              final up = ShellTvFocus.onArrowUp(event, () {
                onUpEdge!();
                return true;
              });
              if (up == KeyEventResult.handled) return up;
            }
            if (onRightEdge != null &&
                shellTvIsNavigationKey(event) &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              onRightEdge!();
              return KeyEventResult.handled;
            }
            return onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
          }
        : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: ForjaInteractive(
        onTap: onTap,
        autoFocus: autoFocus,
        focusNode: focusNode,
        onKeyEvent: effectiveOnKey,
        tvMeta: tvMeta,
        hoverScale: 1.03,
        pressScale: 0.97,
        // Bottom-left so TV focus scale grows into the action gap, not into
        // the hero ClipRect / bottom inset (which ate the glass border).
        scaleAlignment: Alignment.bottomLeft,
        builder: (active, pressed) {
          return HeroPillPlaySurface(
            style: style,
            active: active,
            pressed: pressed,
            expanded: alwaysShowLabel || active,
            label: label,
            leading: leading,
          );
        },
      ),
    );
  }
}

class HeroPillIconSlot {
  const HeroPillIconSlot({
    this.icon,
    this.iconWidget,
    this.onTap,
    this.tooltip,
    this.label,
    this.suppressActive = false,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? label;

  /// Menu open on desktop — keep the trigger idle while hovering menu rows.
  final bool suppressActive;
}

/// Horizontal hero CTA cluster - spatial ←/→ on TV, no escape to catalog.
class HeroPillActionRow extends StatelessWidget {
  const HeroPillActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return row;
    }
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: row,
    );
  }
}

/// Secondary hero actions in one sliced glass pill — hover / focus expands the slot with its label.
class HeroPillIconGroup extends StatelessWidget {
  const HeroPillIconGroup({
    super.key,
    required this.slots,
    this.tvFocusOrderStart,
    this.tvTabId,
    this.onUpEdge,
    this.onRightEdge,
    this.tvRowId,
    this.tvItemIndexStart,
  });

  final List<HeroPillIconSlot> slots;
  final int? tvFocusOrderStart;
  final String? tvTabId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final String? tvRowId;
  final int? tvItemIndexStart;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();

    final useTvCompact = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return HeroPillGlassShell(
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0) const HeroPillSlotDivider(),
          _HeroPillGroupedSlot(
            label: slots[i].label ?? '',
            icon: slots[i].icon,
            iconWidget: slots[i].iconWidget,
            onTap: slots[i].onTap,
            suppressActive: slots[i].suppressActive,
            isFirst: i == 0,
            isLast: i == slots.length - 1,
            useTvCompact: useTvCompact,
            tvTabId: tvTabId,
            onUpEdge: onUpEdge,
            onRightEdge: i == slots.length - 1 ? onRightEdge : null,
            tvRowId: tvRowId,
            tvItemIndex: tvItemIndexStart != null
                ? tvItemIndexStart! + i
                : null,
            focusOrder: tvFocusOrderStart != null
                ? NumericFocusOrder((tvFocusOrderStart! + i).toDouble())
                : null,
          ),
        ],
      ],
    );
  }
}

class HeroPillSegment<T> {
  const HeroPillSegment({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// Segmented hero pill (e.g. SUB | DUB / Providers | Live TV) — glass shell,
/// green label when selected; translucent green fill on hover / D-pad focus.
class HeroPillSegmentedChoice<T> extends StatelessWidget {
  const HeroPillSegmentedChoice({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndexStart,
    this.onUpEdge,
    this.onLeftEdge,
    this.onDownEdge,
  });

  final List<HeroPillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final useTvCompact = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return HeroPillGlassShell(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const HeroPillSlotDivider(),
          _HeroPillSegmentButton<T>(
            segment: segments[i],
            selected: segments[i].value == selected,
            isFirst: i == 0,
            isLast: i == segments.length - 1,
            onTap: () => onSelected(segments[i].value),
            useTvCompact: useTvCompact,
            tvTabId: tvTabId,
            tvRowId: tvRowId,
            tvItemIndex: tvItemIndexStart != null
                ? tvItemIndexStart! + i
                : null,
            onUpEdge: onUpEdge,
            onDownEdge: onDownEdge,
            onLeftEdge: i == 0 ? onLeftEdge : null,
          ),
        ],
      ],
    );
  }
}

class _HeroPillSegmentButton<T> extends StatelessWidget {
  const _HeroPillSegmentButton({
    required this.segment,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.useTvCompact,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
  });

  final HeroPillSegment<T> segment;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final bool useTvCompact;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;

  @override
  Widget build(BuildContext context) {
    final tvMeta = tvTabId != null && useTvCompact
        ? ShellTvFocusMeta(
            tabId: tvTabId!,
            zone: tvRowId != null && tvItemIndex != null
                ? ShellTvZone.row
                : ShellTvZone.hero,
            rowId: tvRowId,
            itemIndex: tvItemIndex,
          )
        : null;
    final effectiveOnKey =
        (onUpEdge != null || onDownEdge != null || onLeftEdge != null)
        ? (FocusNode node, KeyEvent event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (onLeftEdge != null &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              onLeftEdge!();
              return KeyEventResult.handled;
            }
            if (onUpEdge != null &&
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              onUpEdge!();
              return KeyEventResult.handled;
            }
            if (onDownEdge != null &&
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              onDownEdge!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
        : null;

    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.03,
      pressScale: 0.97,
      tvMeta: tvMeta,
      onKeyEvent: effectiveOnKey,
      builder: (hover, pressed) {
        return HeroPillSegmentSurface(
          label: segment.label,
          icon: segment.icon,
          selected: selected,
          lit: hover || pressed,
          pressed: pressed,
          isFirst: isFirst,
          isLast: isLast,
        );
      },
    );
  }
}

class _HeroPillGroupedSlot extends StatelessWidget {
  const _HeroPillGroupedSlot({
    required this.label,
    required this.isFirst,
    required this.isLast,
    required this.useTvCompact,
    this.icon,
    this.iconWidget,
    this.onTap,
    this.suppressActive = false,
    this.focusOrder,
    this.tvTabId,
    this.onUpEdge,
    this.onRightEdge,
    this.tvRowId,
    this.tvItemIndex,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final bool suppressActive;
  final bool isFirst;
  final bool isLast;
  final bool useTvCompact;
  final FocusOrder? focusOrder;
  final String? tvTabId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final String? tvRowId;
  final int? tvItemIndex;

  Widget _wrapOrder(Widget child) {
    final order = focusOrder;
    if (order == null) return child;
    return FocusTraversalOrder(order: order, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final tvMeta = tvTabId != null && useTvCompact
        ? ShellTvFocusMeta(
            tabId: tvTabId!,
            zone: tvRowId != null && tvItemIndex != null
                ? ShellTvZone.row
                : ShellTvZone.hero,
            rowId: tvRowId,
            itemIndex: tvItemIndex,
          )
        : null;
    final effectiveOnKey = onUpEdge != null || onRightEdge != null
        ? (FocusNode node, KeyEvent event) {
            if (onUpEdge != null) {
              final up = ShellTvFocus.onArrowUp(event, () {
                onUpEdge!();
                return true;
              });
              if (up == KeyEventResult.handled) return up;
            }
            if (onRightEdge != null &&
                shellTvIsNavigationKey(event) &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              onRightEdge!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
        : null;

    return _wrapOrder(
      ForjaInteractive(
        onTap: onTap,
        onKeyEvent: effectiveOnKey,
        tvMeta: tvMeta,
        hoverScale: 1,
        pressScale: 1,
        builder: (active, pressed) {
          final lit = suppressActive ? false : active;
          return HeroPillGroupedSlotSurface(
            label: label,
            icon: icon,
            iconWidget: iconWidget,
            active: lit,
            pressed: suppressActive ? false : pressed,
            compact: !lit,
            isFirst: isFirst,
            isLast: isLast,
          );
        },
      ),
    );
  }
}
