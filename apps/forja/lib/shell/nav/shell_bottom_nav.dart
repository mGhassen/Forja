import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shell/nav/pack_update_nav_chrome.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';

import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

class ShellBottomNav extends StatelessWidget {
  const ShellBottomNav({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ShellTokens.bottomNavHeight,
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: visibleIds.asMap().entries.map((entry) {
                final idx = entry.key;
                final id = entry.value;
                final dest = navDestinationFor(id);
                if (dest == null) return const SizedBox.shrink();
                final isSelected = selectedIndex == idx;

                return _BottomNavItem(
                  destination: dest,
                  selected: isSelected,
                  onTap: () => onItemTapped(idx),
                  onLongPress: VerticalFiltersRegistry.hasFilters(id)
                      ? () => VerticalFiltersRegistry.showMenu(id)
                      : null,
                  shareFilterMenuTapGroup:
                      VerticalFiltersRegistry.hasFilters(id),
                );
              }).toList(),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: ShellTokens.bottomNavFadeWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      AppTheme.bgDark.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: ShellTokens.bottomNavFadeIconSize,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.shareFilterMenuTapGroup = false,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Same [TapRegion] group as [VerticalFiltersRail] so re-press opens
  /// without the tap counting as outside and hiding the menu.
  final bool shareFilterMenuTapGroup;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _hover = false;
  bool _focused = false;
  Timer? _completeReloadHoldTimer;
  bool _completeReloadHoldFired = false;

  bool get _active => _hover || _focused;

  void _startCompleteReloadHold() {
    _completeReloadHoldFired = false;
    _completeReloadHoldTimer?.cancel();
    _completeReloadHoldTimer = Timer(ShellTokens.navCompleteReloadHold, () {
      if (!mounted) return;
      _completeReloadHoldFired = true;
      VerticalFiltersRegistry.hideMenu(widget.destination.id);
      HapticFeedback.mediumImpact();
      ShellBus.requestCompleteNavbarReload();
    });
  }

  void _cancelCompleteReloadHold() {
    _completeReloadHoldTimer?.cancel();
    _completeReloadHoldTimer = null;
  }

  bool _consumeCompleteReloadHold() {
    _cancelCompleteReloadHold();
    if (!_completeReloadHoldFired) return false;
    _completeReloadHoldFired = false;
    return true;
  }

  @override
  void dispose() {
    _cancelCompleteReloadHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;
    Widget icon = NavDestinationIcon(
      destination: widget.destination,
      selected: isSelected,
      color: isSelected ? Colors.white : Colors.white54,
      size: ShellTokens.navRailIconSize,
    );
    if (widget.destination.id == 'settings') {
      icon = PackUpdateNavChrome(
        expanded: _active,
        flyoutAbove: true,
        badgeSize: ShellTokens.packUpdateBadgeSizeBottomNav,
        child: icon,
      );
    }

    Widget item = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (_) => _startCompleteReloadHold(),
          onPointerUp: (_) {
            if (!_completeReloadHoldFired) {
              _cancelCompleteReloadHold();
            }
          },
          onPointerCancel: (_) => _cancelCompleteReloadHold(),
          child: InkWell(
            hoverColor: ForjaShellColors.inkHover,
            splashColor: ForjaShellColors.inkSplash,
            onTap: () {
              if (_consumeCompleteReloadHold()) return;
              widget.onTap();
            },
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    if (_completeReloadHoldFired) return;
                    widget.onLongPress!();
                  },
            child: SizedBox(
              width: ShellTokens.bottomNavItemWidth,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: ShellTokens.navSelectionAnimation,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ShellTokens.bottomNavIconPaddingH,
                        vertical: ShellTokens.bottomNavIconPaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ForjaShellColors.chipSelectedBg
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          ShellTokens.navSelectionBorderRadius,
                        ),
                      ),
                      child: icon,
                    ),
                    const SizedBox(height: ShellTokens.bottomNavIconLabelGap),
                    Text(
                      widget.destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: ShellTokens.bottomNavLabelSize,
                        height: 1,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
