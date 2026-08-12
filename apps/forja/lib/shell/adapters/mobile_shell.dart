import 'package:flutter/material.dart';
import 'package:forja/shell/shell_scaffold.dart';

/// Passthrough to bottom-nav shell; landscape uses nav rail (existing behavior).
class MobileShell extends StatelessWidget {
  const MobileShell({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.mountedTabIds,
    required this.onDestinationSelected,
    required this.tabFor,
    this.shellHeader,
    this.shellTopBar,
    this.hideGlobalNav = false,
  });

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
    // Keep landscape rail mounted while Offstage (IPTV) — do not tie
    // useNavRail to hideGlobalNav or exit remounts the rail.
    final useNavRail =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return ShellScaffold(
      useNavRail: useNavRail,
      visibleIds: visibleIds,
      selectedIndex: selectedIndex,
      mountedTabIds: mountedTabIds,
      onDestinationSelected: onDestinationSelected,
      tabFor: tabFor,
      shellHeader: shellHeader,
      shellTopBar: shellTopBar,
      hideGlobalNav: hideGlobalNav,
    );
  }
}
