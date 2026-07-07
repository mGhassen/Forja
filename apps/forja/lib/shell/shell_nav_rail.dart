import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellNavRail extends StatefulWidget {
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

  @override
  State<ShellNavRail> createState() => _ShellNavRailState();
}

class _ShellNavRailState extends State<ShellNavRail> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final topPadding = widget.isDesktop && Platform.isMacOS
        ? ShellTokens.navRailLogoTopPaddingDesktopMac
        : ShellTokens.navRailLogoTopPaddingDefault;

    final width = _hovered
        ? ShellTokens.navRailExpandedWidth
        : ShellTokens.navRailCollapsedWidth;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: ShellTokens.navRailExpandDuration,
        curve: Curves.easeOutCubic,
        width: width,
        clipBehavior: Clip.hardEdge,
        color: AppTheme.bgDark,
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  topPadding,
                  0,
                  ShellTokens.navRailLogoBottomPadding,
                ),
                child: Image.asset(
                  AppTheme.isLightMode
                      ? 'assets/icon/logo-light.png'
                      : 'assets/icon/logo-dark.png',
                  width: ShellTokens.navRailLogoWidth,
                  fit: BoxFit.contain,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: widget.visibleIds.length,
                  itemBuilder: (context, index) {
                    final id = widget.visibleIds[index];
                    final dest = navDestinations[id]!;
                    final selected = index == widget.selectedIndex;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final showLabels = constraints.maxWidth >
                            ShellTokens.navRailCollapsedWidth + 20;
                        return _ShellNavRailItem(
                          destination: dest,
                          selected: selected,
                          expanded: _hovered && showLabels,
                          onTap: () => widget.onDestinationSelected(index),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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
    required this.expanded,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? destination.activeIcon : destination.icon,
      color: selected ? Colors.white : Colors.white54,
      size: 24,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ShellTokens.navSelectionBorderRadius),
          child: ClipRect(
            child: AnimatedContainer(
              duration: ShellTokens.navSelectionAnimation,
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 12 : 8,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.current.primaryColor.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(ShellTokens.navSelectionBorderRadius),
              ),
              child: Row(
                children: [
                  icon,
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
