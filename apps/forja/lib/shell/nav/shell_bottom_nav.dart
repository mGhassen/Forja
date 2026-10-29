import 'package:flutter/material.dart';
import 'package:forja/shell/nav/nav_complete_reload_hold.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shell/nav/pack_update_nav_chrome.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';

import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Touch shell bottom bar.
///
/// Shows at most [ShellTokens.bottomNavMaxSlots] slots. With more tabs, the
/// last slot is "More" and opens a sheet listing the rest, in the same order
/// as [visibleIds] (Settings → Features). Landscape phones get a compact bar
/// with icon and label side by side. The bar pads itself for the bottom and
/// side system insets (gesture pill, 3-button nav, cutouts).
class ShellBottomNav extends StatefulWidget {
  const ShellBottomNav({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  /// Synthetic slot id — never a pack or core nav id.
  static const moreSlotId = '__shell_bottom_nav_more__';

  static const _moreDestination = NavDestination(
    id: moreSlotId,
    icon: Icons.more_horiz_rounded,
    activeIcon: Icons.more_horiz_rounded,
    label: 'More',
  );

  /// Landscape phones use the compact bar.
  static bool compactOf(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Bar height above the bottom system inset.
  static double barHeightOf(BuildContext context) => compactOf(context)
      ? ShellTokens.bottomNavHeightCompact
      : ShellTokens.bottomNavHeight;

  /// Splits [visibleIds] into bar slots and "More" sheet entries.
  ///
  /// Indexes stay indexes into [visibleIds]. Ids without a destination are
  /// skipped (they never painted).
  static ({List<int> bar, List<int> more}) slotsFor(List<String> visibleIds) {
    final painted = <int>[
      for (var i = 0; i < visibleIds.length; i++)
        if (navDestinationFor(visibleIds[i]) != null) i,
    ];
    if (painted.length <= ShellTokens.bottomNavMaxSlots) {
      return (bar: painted, more: const <int>[]);
    }
    final split = ShellTokens.bottomNavMaxSlots - 1;
    return (bar: painted.sublist(0, split), more: painted.sublist(split));
  }

  @override
  State<ShellBottomNav> createState() => _ShellBottomNavState();
}

class _ShellBottomNavState extends State<ShellBottomNav> {
  /// The sheet pops a nav id, resolved against the ids current when it
  /// closes: tabs can change while it is open (pack install, sign-in).
  Future<void> _openMoreSheet(BuildContext context, List<int> more) async {
    final direction = Directionality.of(context);
    // Snapshot: the route builder re-runs on rebuilds, and [more] indexes
    // this list, not a later one.
    final ids = widget.visibleIds;
    final selectedIndex = widget.selectedIndex;
    final pickedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ShellTokens.bottomNavMoreSheetRadius),
        ),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: direction,
        child: _BottomNavMoreSheet(
          visibleIds: ids,
          indexes: more,
          selectedIndex: selectedIndex,
        ),
      ),
    );
    if (pickedId == null || !mounted) return;
    final idx = widget.visibleIds.indexOf(pickedId);
    if (idx >= 0) widget.onItemTapped(idx);
  }

  @override
  Widget build(BuildContext context) {
    final compact = ShellBottomNav.compactOf(context);
    final insets = MediaQuery.paddingOf(context);
    final slots = ShellBottomNav.slotsFor(widget.visibleIds);
    final moreSelected = slots.more.contains(widget.selectedIndex);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: insets.left,
          right: insets.right,
          bottom: insets.bottom,
        ),
        child: SizedBox(
          height: ShellBottomNav.barHeightOf(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final idx in slots.bar)
                Expanded(
                  child: _BottomNavItem(
                    destination: navDestinationFor(widget.visibleIds[idx])!,
                    selected: widget.selectedIndex == idx,
                    compact: compact,
                    showPackUpdateBadge: widget.visibleIds[idx] == 'settings',
                    onTap: () => widget.onItemTapped(idx),
                    onLongPress:
                        VerticalFiltersRegistry.hasFilters(widget.visibleIds[idx])
                        ? () => VerticalFiltersRegistry.showMenu(
                            widget.visibleIds[idx],
                          )
                        : null,
                    shareFilterMenuTapGroup: VerticalFiltersRegistry.hasFilters(
                      widget.visibleIds[idx],
                    ),
                  ),
                ),
              if (slots.more.isNotEmpty)
                Expanded(
                  child: _BottomNavItem(
                    key: const ValueKey(ShellBottomNav.moreSlotId),
                    destination: ShellBottomNav._moreDestination,
                    selected: moreSelected,
                    compact: compact,
                    showPackUpdateBadge: slots.more.any(
                      (i) => widget.visibleIds[i] == 'settings',
                    ),
                    reloadHold: false,
                    onTap: () => _openMoreSheet(context, slots.more),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.onLongPress,
    this.shareFilterMenuTapGroup = false,
    this.showPackUpdateBadge = false,
    this.reloadHold = true,
  });

  final NavDestination destination;
  final bool selected;

  /// Landscape phone: icon and label side by side.
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Same [TapRegion] group as [VerticalFiltersRail] so re-press opens
  /// without the tap counting as outside and hiding the menu.
  final bool shareFilterMenuTapGroup;

  /// Settings slot (or "More" holding Settings): pack update badge.
  final bool showPackUpdateBadge;

  /// Hold-to-reload a tab. Off for "More" (not a tab).
  final bool reloadHold;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _hover = false;
  bool _focused = false;
  late final NavCompleteReloadHold _reloadHold;

  bool get _active => _hover || _focused;

  @override
  void initState() {
    super.initState();
    _reloadHold = NavCompleteReloadHold(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _reloadHold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;
    final compact = widget.compact;
    final iconSize = compact
        ? ShellTokens.bottomNavIconSizeCompact
        : ShellTokens.navRailIconSize;
    final color = isSelected ? Colors.white : Colors.white54;
    Widget icon = NavDestinationIcon(
      destination: widget.destination,
      selected: isSelected,
      color: color,
      size: iconSize,
    );
    if (widget.showPackUpdateBadge) {
      icon = PackUpdateNavChrome(
        expanded: _active,
        flyoutAbove: true,
        badgeSize: ShellTokens.packUpdateBadgeSizeBottomNav,
        child: icon,
      );
    }
    if (widget.reloadHold) {
      icon = NavReloadHoldIcon(
        icon: icon,
        loading: _reloadHold.loading,
        size: iconSize,
      );
    }

    final pill = AnimatedContainer(
      duration: ShellTokens.navSelectionAnimation,
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? ShellTokens.bottomNavIconPaddingHCompact
            : ShellTokens.bottomNavIconPaddingH,
        vertical: ShellTokens.bottomNavIconPaddingV,
      ),
      decoration: BoxDecoration(
        color: isSelected ? ForjaShellColors.chipSelectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(
          ShellTokens.navSelectionBorderRadius,
        ),
      ),
      child: icon,
    );
    final label = Text(
      widget.destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: compact
            ? ShellTokens.bottomNavLabelSizeCompact
            : ShellTokens.bottomNavLabelSize,
        height: 1,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
    final content = compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pill,
              const SizedBox(width: ShellTokens.bottomNavIconLabelGapCompact),
              Flexible(child: label),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pill,
              const SizedBox(height: ShellTokens.bottomNavIconLabelGap),
              label,
            ],
          );

    Widget item = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: widget.reloadHold
              ? (e) => _reloadHold.pointerDown(
                  e,
                  hideMenuTabId: widget.destination.id,
                )
              : null,
          onPointerUp: widget.reloadHold ? _reloadHold.pointerUp : null,
          onPointerCancel: widget.reloadHold ? _reloadHold.pointerCancel : null,
          child: InkWell(
            hoverColor: ForjaShellColors.inkHover,
            splashColor: ForjaShellColors.inkSplash,
            onTap: () {
              if (_reloadHold.consumeCompleted()) return;
              widget.onTap();
            },
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    if (_reloadHold.didComplete) return;
                    widget.onLongPress!();
                  },
            child: Center(child: content),
          ),
        ),
      ),
    );
    if (widget.shareFilterMenuTapGroup) {
      item = TapRegion(
        groupId: VerticalFiltersRegistry.menuTapGroup,
        child: item,
      );
    }
    return item;
  }
}

/// Tabs past the bar slots — same icons and labels as the bar. Pops with the
/// picked nav id.
class _BottomNavMoreSheet extends StatelessWidget {
  const _BottomNavMoreSheet({
    required this.visibleIds,
    required this.indexes,
    required this.selectedIndex,
  });

  final List<String> visibleIds;
  final List<int> indexes;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    // Side insets (landscape cutout) pad each row's content, not the row,
    // so the selected highlight still spans the sheet.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(
          vertical: ShellTokens.bottomNavMoreSheetPadV,
        ),
        children: [
          for (final idx in indexes)
            _BottomNavMoreRow(
              key: ValueKey('bottom-nav-more-${visibleIds[idx]}'),
              destination: navDestinationFor(visibleIds[idx])!,
              selected: idx == selectedIndex,
              showPackUpdateBadge: visibleIds[idx] == 'settings',
              onTap: () => Navigator.of(context).pop(visibleIds[idx]),
              onLongPress: VerticalFiltersRegistry.hasFilters(visibleIds[idx])
                  ? () {
                      final id = visibleIds[idx];
                      Navigator.of(context).pop(id);
                      VerticalFiltersRegistry.showMenu(id);
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

class _BottomNavMoreRow extends StatelessWidget {
  const _BottomNavMoreRow({
    super.key,
    required this.destination,
    required this.selected,
    required this.showPackUpdateBadge,
    required this.onTap,
    this.onLongPress,
  });

  final NavDestination destination;
  final bool selected;
  final bool showPackUpdateBadge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white54;
    Widget icon = NavDestinationIcon(
      destination: destination,
      selected: selected,
      color: color,
      size: ShellTokens.bottomNavMoreIconSize,
    );
    if (showPackUpdateBadge) {
      icon = PackUpdateNavChrome(
        expanded: false,
        badgeSize: ShellTokens.packUpdateBadgeSizeBottomNav,
        child: icon,
      );
    }
    return InkWell(
      hoverColor: ForjaShellColors.inkHover,
      splashColor: ForjaShellColors.inkSplash,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: ShellTokens.bottomNavMoreRowHeight,
        color: selected ? ForjaShellColors.chipSelectedBg : null,
        padding: EdgeInsetsDirectional.only(
          start: ShellTokens.bodyHorizontalPadding,
          end: ShellTokens.bodyHorizontalPadding,
        ).add(
          EdgeInsets.only(
            left: MediaQuery.paddingOf(context).left,
            right: MediaQuery.paddingOf(context).right,
          ),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: ShellTokens.bottomNavMoreRowGap),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: ShellTokens.bottomNavMoreLabelSize,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
