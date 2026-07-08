import 'package:flutter/material.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellScaffold extends StatefulWidget {
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
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onNavSelected(int index) {
    popShellOverlayUntilRoot();
    widget.onDestinationSelected(index);
    final width = MediaQuery.sizeOf(context).width;
    final compactNav = widget.useNavRail &&
        !widget.hideGlobalNav &&
        width < ShellTokens.shellNavCompactMaxWidth;
    if (compactNav) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showRail = widget.useNavRail && !widget.hideGlobalNav;
    final compactNav =
        showRail && width < ShellTokens.shellNavCompactMaxWidth;
    final bodyInset =
        showRail && !compactNav ? ShellTokens.navRailWidth : 0.0;

    return Scaffold(
      key: _scaffoldKey,
      drawer: compactNav
          ? Drawer(
              width: ShellTokens.navRailWidth,
              backgroundColor: AppTheme.bgDark,
              child: ShellNavRail(
                visibleIds: widget.visibleIds,
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: _onNavSelected,
                isDesktop: widget.isDesktop,
              ),
            )
          : null,
      body: Stack(
        children: [
          Container(decoration: AppTheme.effectiveBackground),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(left: bodyInset),
              child: Column(
                children: [
                  if (widget.shellHeader != null) widget.shellHeader!,
                  Expanded(
                    child: Stack(
                      children: [
                        ShellBody(
                          selectedIndex: widget.selectedIndex,
                          visibleIds: widget.visibleIds,
                          mountedTabIds: widget.mountedTabIds,
                          tabFor: widget.tabFor,
                        ),
                        const Positioned.fill(
                          child: ShellOverlayNavigator(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.shellTopBar != null)
            Positioned(
              top: 0,
              left: bodyInset,
              right: 0,
              child: widget.shellTopBar!,
            ),
          if (compactNav && widget.shellTopBar == null)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: ShellTokens.bodyHorizontalPadding,
                    top: ShellTokens.shellHeaderTopPadding,
                  ),
                  child: ShellNavMenuButton(
                    onPressed: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
              ),
            ),
          if (showRail && !compactNav)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ShellNavRail(
                visibleIds: widget.visibleIds,
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: _onNavSelected,
                isDesktop: widget.isDesktop,
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.useNavRail || widget.hideGlobalNav
          ? null
          : ShellBottomNav(
              visibleIds: widget.visibleIds,
              selectedIndex: widget.selectedIndex,
              onItemTapped: _onNavSelected,
            ),
    );
  }
}
