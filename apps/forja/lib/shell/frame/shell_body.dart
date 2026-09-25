import 'package:flutter/material.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';

class ShellBody extends StatelessWidget {
  const ShellBody({
    super.key,
    required this.selectedIndex,
    required this.visibleIds,
    required this.mountedTabIds,
    required this.tabFor,
  });

  final int selectedIndex;
  final List<String> visibleIds;
  final Set<String> mountedTabIds;
  final Widget Function(String id) tabFor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.playerSurfaceActive,
      builder: (context, playerActive, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ShellBus.shellOverlayHasPage,
          builder: (context, overlayOpen, _) {
            return ExcludeFocus(
              excluding: overlayOpen || playerActive,
              // Do not use IndexedStack here: it wraps each child in an unkeyed
              // Visibility, so KeyedSubtree keys never reach the Stack. Enabling
              // or reordering a nav tab then remounts other tabs (e.g. Settings
              // loses its selected category and appears to "reload").
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < visibleIds.length; i++)
                    Visibility(
                      key: ValueKey<String>('shell-tab-${visibleIds[i]}'),
                      visible: i == selectedIndex,
                      maintainState: true,
                      // Offstage, not maintainSize. maintainSize laid out every
                      // kept-alive hub on each shell rebuild, so a click waited
                      // on four other full pages.
                      maintainAnimation: true,
                      maintainSize: false,
                      maintainInteractivity: false,
                      child: TickerMode(
                        // Hidden tabs, and the selected tab under a fullscreen
                        // player, must not keep tickers alive — wastes CPU on
                        // ATV while decode needs the SoC.
                        enabled: i == selectedIndex && !playerActive,
                        child: _tabSlot(
                          context,
                          index: i,
                          tabId: visibleIds[i],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Selected + not yet mounted used to paint [SizedBox.shrink] — blank hub
  /// (no loading ticker, no pack structure) after pack reload / remount races.
  Widget _tabSlot(
    BuildContext context, {
    required int index,
    required String tabId,
  }) {
    if (mountedTabIds.contains(tabId)) {
      return tabFor(tabId);
    }
    if (index == selectedIndex) {
      return hubNeutralLoadingSkeleton(context, tabId: tabId);
    }
    return const SizedBox.shrink();
  }
}
