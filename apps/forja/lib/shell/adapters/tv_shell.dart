import 'package:flutter/material.dart';
import 'package:forja/shell/shell_scaffold.dart';

class TvShell extends StatelessWidget {
  const TvShell({
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
    return ShellScaffold(
      // Always a rail profile — [hideGlobalNav] only hides it Offstage so player
      // enter/exit does not dispose/recreate [ShellNavRail] (TV remount flash).
      useNavRail: true,
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
