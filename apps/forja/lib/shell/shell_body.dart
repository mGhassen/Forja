import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';

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
      valueListenable: ShellBus.shellOverlayHasPage,
      builder: (context, overlayOpen, _) {
        return ExcludeFocus(
          excluding: overlayOpen,
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
                  maintainAnimation: true,
                  maintainSize: true,
                  // Hidden tabs must not hit-test. With maintainInteractivity,
                  // later mounted tabs sit above the selected one in this Stack
                  // and swallow hover/clicks (e.g. IPTV "frozen" after visiting
                  // Settings / Live Matches).
                  maintainInteractivity: false,
                  child: mountedTabIds.contains(visibleIds[i])
                      ? tabFor(visibleIds[i])
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
    );
  }
}
