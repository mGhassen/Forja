import 'package:flutter/material.dart';
import 'package:forja/shell/frame/shell_body.dart';
import 'package:forja/shell/nav/shell_bottom_nav.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/nav/shell_nav_rail.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';

import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja_foundation/blocks/shell/shell_nav_placement.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Host chassis scaffold — composes nav + body + overlays.
///
/// Target shape for peel: [EmptyShellFrame] in `forja_foundation` (rail + body
/// only). Product chrome stays in packs / kit painter; this file must not grow
/// Home/Search vocabulary.
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

  bool _navRtl = false;

  void _openNavDrawer() {
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    if (_navRtl) {
      state.openEndDrawer();
    } else {
      state.openDrawer();
    }
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
        return ValueListenableBuilder<String>(
          valueListenable: SettingsService.shellWritingDirection,
          builder: (context, direction, _) {
            return _buildShell(
              context,
              emptyFeaturesGate: emptyGate,
              layoutRtl: direction == SettingsService.shellWritingRtl,
            );
          },
        );
      },
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required bool emptyFeaturesGate,
    required bool layoutRtl,
  }) {
    _navRtl = layoutRtl;
    final placement = ShellNavPlacement(
      textDirection: layoutRtl ? TextDirection.rtl : TextDirection.ltr,
    );
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
    // Desktop empty get-started: full-bleed (rail overlays).
    // TV: body-center with rail inset — screen-centering a narrow card row
    // next to a permanent rail reads as off-center on leanback.
    final contentPadding = (emptyFeaturesGate && !metrics.usesTvDensity)
        ? placement.contentPadding(
            railWidth: 0,
            safeLeft: tvSafeLeft,
            safeRight: tvSafeRight,
          )
        : placement.contentPadding(
            railWidth: railWidth,
            safeLeft: tvSafeLeft,
            safeRight: tvSafeRight,
          );

    Widget body = Stack(
      children: [
        Container(decoration: AppTheme.effectiveBackground),
        Positioned.fill(
          child: Padding(
            padding: contentPadding,
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
        // later Stack children (nav) onto the wrong Elements.
        Positioned(
          key: const ValueKey('shell-kit-top-bar'),
          top: 0,
          left: contentPadding.left,
          right: contentPadding.right,
          child: widget.shellTopBar ?? const SizedBox.shrink(),
        ),
        // Compact ☰ always lives here — even when a pack hub mounts an empty
        // shellTopBar (layout-only hubs). Kit chrome pads for this lane; it
        // must not paint a second button.
        if (compactNav) ...[
          Positioned(
            top: 0,
            left: placement.railOnRight ? null : tvSafeLeft,
            right: placement.railOnRight ? tvSafeRight : null,
            child: SafeArea(
              bottom: false,
              left: false,
              right: false,
              child: Padding(
                padding: placement.compactMenuPadding(
                  leading: ShellTokens.compactMenuLeadingInset(context),
                  top: ShellTokens.shellHeaderTopPadding,
                ),
                child: ShellNavMenuButton(onPressed: _openNavDrawer),
              ),
            ),
          ),
          Positioned(
            left: placement.railOnRight ? null : tvSafeLeft,
            right: placement.railOnRight ? tvSafeRight : null,
            top: 0,
            bottom: 0,
            width: ShellTokens.compactNavEdgeHoverWidth,
            child: MouseRegion(
              onEnter: (_) => _openNavDrawer(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
        if (mountRail)
          Positioned(
            key: const ValueKey('shell-nav-rail'),
            left: placement.railOnRight ? null : tvSafeLeft,
            right: placement.railOnRight ? tvSafeRight : null,
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
                    pageDirection: placement.textDirection,
                  ),
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

    final navDrawer = compactNav
        ? Drawer(
            width: metrics.navRailWidth,
            backgroundColor: AppTheme.bgDark,
            child: ShellNavRail(
              visibleIds: widget.visibleIds,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _onNavSelected,
              hideLogo: emptyFeaturesGate,
              pageDirection: placement.textDirection,
            ),
          )
        : null;
    Widget shell = Scaffold(
      key: _scaffoldKey,
      drawer: placement.railOnRight ? null : navDrawer,
      endDrawer: placement.railOnRight ? navDrawer : null,
      body: body,
      bottomNavigationBar: widget.useNavRail || widget.hideGlobalNav
          ? null
          : Directionality(
              textDirection: placement.textDirection,
              child: ShellBottomNav(
                visibleIds: widget.visibleIds,
                selectedIndex: widget.selectedIndex,
                onItemTapped: _onNavSelected,
              ),
            ),
    );

    return shell;
  }
}
