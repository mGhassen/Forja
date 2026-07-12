import 'package:flutter/material.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({
    super.key,
    required this.useNavRail,
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

  bool _compactNav(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final showRail = widget.useNavRail && !widget.hideGlobalNav;
    return showRail &&
        metrics.allowCompactNavDrawer &&
        width < ShellTokens.shellNavCompactMaxWidth;
  }

  void _onNavSelected(int index) {
    popShellOverlayUntilRoot();
    widget.onDestinationSelected(index);
    if (_compactNav(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    ShellTvFocusCoordinator.tvBackPolicyEnabled = policy.useFocusableMoodChips;
    if (policy.useFocusableMoodChips &&
        widget.visibleIds.isNotEmpty &&
        widget.selectedIndex < widget.visibleIds.length) {
      ShellTvFocus.currentNavTabId = widget.visibleIds[widget.selectedIndex];
    }

    final metrics = ShellScope.metricsOf(context);
    final showRail = widget.useNavRail && !widget.hideGlobalNav;
    final compactNav = _compactNav(context);
    final tvSafeLeft = shellTvSafeHorizontalInset(context);
    final tvSafeRight = shellTvSafeHorizontalInsetRight(context);
    final railWidth =
        showRail && !compactNav ? metrics.navRailWidth : 0.0;
    final contentLeftInset = tvSafeLeft + railWidth;

    Widget body = Stack(
      children: [
        Container(decoration: AppTheme.effectiveBackground),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              left: contentLeftInset,
              right: tvSafeRight,
            ),
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
            left: contentLeftInset,
            right: tvSafeRight,
            child: widget.shellTopBar!,
          ),
        if (compactNav && widget.shellTopBar == null)
          Positioned(
            top: 0,
            left: tvSafeLeft,
            child: SafeArea(
              bottom: false,
              left: false,
              right: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: ShellTokens.compactMenuLeadingInset(context),
                  top: ShellTokens.shellHeaderTopPadding,
                ),
                child: ShellNavMenuButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
            ),
          ),
        if (showRail && !compactNav)
          Positioned(
            left: tvSafeLeft,
            top: 0,
            bottom: 0,
            child: ShellNavRail(
              visibleIds: widget.visibleIds,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _onNavSelected,
            ),
          ),
      ],
    );

    if (tvSafeLeft > 0 || tvSafeRight > 0) {
      body = MediaQuery.removePadding(
        context: context,
        removeLeft: tvSafeLeft > 0,
        removeRight: tvSafeRight > 0,
        child: body,
      );
    }

    Widget shell = Scaffold(
      key: _scaffoldKey,
      drawer: compactNav
          ? Drawer(
              width: metrics.navRailWidth,
              backgroundColor: AppTheme.bgDark,
              child: ShellNavRail(
                visibleIds: widget.visibleIds,
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: _onNavSelected,
              ),
            )
          : null,
      body: body,
      bottomNavigationBar: widget.useNavRail || widget.hideGlobalNav
          ? null
          : ShellBottomNav(
              visibleIds: widget.visibleIds,
              selectedIndex: widget.selectedIndex,
              onItemTapped: _onNavSelected,
            ),
    );

    return shell;
  }
}
