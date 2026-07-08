import 'package:flutter/material.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.useNavRail,
    required this.isDesktop,
    required this.visibleIds,
    required this.selectedIndex,
    required this.mountedTabIds,
    required this.onDestinationSelected,
    required this.tabFor,
    this.shellHeader,
    this.shellTopBar,
    this.hideGlobalNav = false,
  });

  final bool useNavRail;
  final bool isDesktop;
  final List<String> visibleIds;
  final int selectedIndex;
  final Set<String> mountedTabIds;
  final ValueChanged<int> onDestinationSelected;
  final Widget Function(String id) tabFor;
  final Widget? shellHeader;
  final Widget? shellTopBar;
  final bool hideGlobalNav;

  @override
  Widget build(BuildContext context) {
    final showRail = useNavRail && !hideGlobalNav;
    final bodyInset = showRail ? ShellTokens.navRailWidth : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.effectiveBackground),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(left: bodyInset),
              child: Column(
                children: [
                  if (shellTopBar != null) shellTopBar!,
                  if (shellHeader != null) shellHeader!,
                  Expanded(
                    child: ShellBody(
                      selectedIndex: selectedIndex,
                      visibleIds: visibleIds,
                      mountedTabIds: mountedTabIds,
                      tabFor: tabFor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showRail)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ShellNavRail(
                visibleIds: visibleIds,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                isDesktop: isDesktop,
              ),
            ),
        ],
      ),
      bottomNavigationBar: useNavRail || hideGlobalNav
          ? null
          : ShellBottomNav(
              visibleIds: visibleIds,
              selectedIndex: selectedIndex,
              onItemTapped: onDestinationSelected,
            ),
    );
  }
}
