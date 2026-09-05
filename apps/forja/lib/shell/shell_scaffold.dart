import 'package:flutter/material.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters_rail.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
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
    this.maskUnderPlayer = false,
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

  /// Full-window black cover (no layout reflow) while IPTV root player is up.
  final bool maskUnderPlayer;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _compactNav(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    // Compact drawer only when the rail would actually paint — not while the
    // Offstage keep-alive rail is hidden for a player surface.
    final railPainted = widget.useNavRail && !widget.hideGlobalNav;
    return railPainted &&
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
    ShellTvFocusCoordinator.tvBackPolicyEnabled = policy.leanbackOnly;
    if (policy.useFocusableMoodChips &&
        widget.visibleIds.isNotEmpty &&
        widget.selectedIndex < widget.visibleIds.length) {
      ShellTvFocus.currentNavTabId = widget.visibleIds[widget.selectedIndex];
    }

    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.emptyFeaturesGate,
      builder: (context, emptyGate, _) {
        return _buildShell(context, emptyFeaturesGate: emptyGate);
      },
    );
  }

  Widget _buildShell(BuildContext context, {required bool emptyFeaturesGate}) {
    final metrics = ShellScope.metricsOf(context);
    final compactNav = _compactNav(context);
    // Keep the rail Element mounted whenever this profile uses a rail; only
    // paint/layout width when not [hideGlobalNav]. Tearing the rail out for
    // player surfaces caused a cold remount flash on Android TV exit.
    final mountRail = widget.useNavRail && !compactNav;
    final railPainted = mountRail && !widget.hideGlobalNav;
    final tvSafeLeft = shellTvSafeHorizontalInset(context);
    final tvSafeRight = shellTvSafeHorizontalInsetRight(context);
    final railWidth = railPainted ? metrics.navRailWidth : 0.0;
    // Empty get-started: center on the full window (rail overlays; logo hidden).
    final contentLeftInset =
        emptyFeaturesGate ? tvSafeLeft : tvSafeLeft + railWidth;

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
                      const Positioned.fill(child: ShellOverlayNavigator()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Always reserve this slot so overlay open/close does not reshuffle
        // later Stack children (provider rail / nav) onto the wrong Elements.
        Positioned(
          key: const ValueKey('shell-home-top-bar'),
          top: 0,
          left: contentLeftInset,
          right: tvSafeRight,
          child: widget.shellTopBar ?? const SizedBox.shrink(),
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
        if (mountRail)
          Positioned(
            key: const ValueKey('shell-nav-rail'),
            left: tvSafeLeft,
            top: 0,
            bottom: 0,
            child: Offstage(
              offstage: widget.hideGlobalNav,
              child: ExcludeFocus(
                excluding: widget.hideGlobalNav,
                child: IgnorePointer(
                  ignoring: widget.hideGlobalNav,
                  child: ShellNavRail(
                    visibleIds: widget.visibleIds,
                    selectedIndex: widget.selectedIndex,
                    onDestinationSelected: _onNavSelected,
                    hideLogo: emptyFeaturesGate,
                  ),
                ),
              ),
            ),
          ),
        // Above the nav rail so the panel stays hittable; keyed so Home
        // re-select / top-bar chrome toggles cannot steal this Element.
        if (!emptyFeaturesGate &&
            widget.visibleIds.isNotEmpty &&
            widget.selectedIndex < widget.visibleIds.length &&
            CatalogVerticalFiltersRegistry.hasFilters(
              widget.visibleIds[widget.selectedIndex],
            ))
          Positioned(
            key: ValueKey(
              'shell-vf-rail-${widget.visibleIds[widget.selectedIndex]}',
            ),
            left: contentLeftInset + ShellTokens.shellProviderRailInset,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CatalogVerticalFiltersRail(
                  tabId: widget.visibleIds[widget.selectedIndex],
                ),
              ),
            ),
          ),
        if (widget.maskUnderPlayer)
          const Positioned.fill(
            key: ValueKey('shell-player-underlay-mask'),
            child: ColoredBox(color: Colors.black),
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
                hideLogo: emptyFeaturesGate,
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
