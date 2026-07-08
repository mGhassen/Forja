import 'package:flutter/material.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellNavRail extends StatelessWidget {
  const ShellNavRail({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isDesktop,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDesktop;

  List<String> get _navIds =>
      visibleIds.where((id) => id != 'settings').toList();

  int? _indexForId(String id) {
    final idx = visibleIds.indexOf(id);
    return idx >= 0 ? idx : null;
  }

  @override
  Widget build(BuildContext context) {
    final settingsIndex = _indexForId('settings');

    return Container(
      width: ShellTokens.navRailWidth,
      color: AppTheme.bgDark,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            const _ProfilePlaceholder(),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _navIds.map((id) {
                  final index = _indexForId(id)!;
                  final dest = navDestinations[id]!;
                  final selected = index == selectedIndex;
                  return _ShellNavRailItem(
                    destination: dest,
                    selected: selected,
                    onTap: () => onDestinationSelected(index),
                  );
                }).toList(),
              ),
            ),
            if (settingsIndex != null) ...[
              _ShellNavRailItem(
                destination: navDestinations['settings']!,
                selected: settingsIndex == selectedIndex,
                onTap: () => onDestinationSelected(settingsIndex),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ShellTokens.navRailWidth,
      child: Center(
        child: CircleAvatar(
          radius: ShellTokens.navRailProfileSize / 2,
          backgroundColor: ForjaShellColors.surfaceElevated,
          child: Icon(
            Icons.person_outline,
            size: 22,
            color: ForjaShellColors.iconMuted,
          ),
        ),
      ),
    );
  }
}

class _ShellNavRailItem extends StatelessWidget {
  const _ShellNavRailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        selected ? ForjaShellColors.iconActive : ForjaShellColors.iconMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: ShellTokens.navRailItemSpacing / 2,
      ),
      child: SizedBox(
        width: ShellTokens.navRailWidth,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? destination.activeIcon : destination.icon,
                    color: iconColor,
                    size: ShellTokens.navRailIconSize,
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: ShellTokens.navSelectionAnimation,
                    height: ShellTokens.shellNavUnderlineHeight,
                    width: selected ? 24 : 0,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.current.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
