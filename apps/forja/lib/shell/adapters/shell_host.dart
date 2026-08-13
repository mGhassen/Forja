import 'package:flutter/material.dart';
import 'package:forja/shell/adapters/desktop_shell.dart';
import 'package:forja/shell/adapters/mobile_shell.dart';
import 'package:forja/shell/adapters/tv_shell.dart';
import 'package:forja/shared/design/design.dart';

/// Single platform switch - picks the shell adapter from [ShellScope.profile].
class ShellHost extends StatelessWidget {
  const ShellHost({
    super.key,
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

  final List<String> visibleIds;
  final int selectedIndex;
  final Set<String> mountedTabIds;
  final ValueChanged<int> onDestinationSelected;
  final Widget Function(String id) tabFor;
  final Widget? shellHeader;
  final Widget? shellTopBar;
  final bool hideGlobalNav;
  final bool maskUnderPlayer;

  @override
  Widget build(BuildContext context) {
    return switch (ShellScope.profileOf(context)) {
      ShellProfile.mobile => MobileShell(
          visibleIds: visibleIds,
          selectedIndex: selectedIndex,
          mountedTabIds: mountedTabIds,
          onDestinationSelected: onDestinationSelected,
          tabFor: tabFor,
          shellHeader: shellHeader,
          shellTopBar: shellTopBar,
          hideGlobalNav: hideGlobalNav,
          maskUnderPlayer: maskUnderPlayer,
        ),
      ShellProfile.desktop => DesktopShell(
          visibleIds: visibleIds,
          selectedIndex: selectedIndex,
          mountedTabIds: mountedTabIds,
          onDestinationSelected: onDestinationSelected,
          tabFor: tabFor,
          shellHeader: shellHeader,
          shellTopBar: shellTopBar,
          hideGlobalNav: hideGlobalNav,
          maskUnderPlayer: maskUnderPlayer,
        ),
      ShellProfile.tv => TvShell(
          visibleIds: visibleIds,
          selectedIndex: selectedIndex,
          mountedTabIds: mountedTabIds,
          onDestinationSelected: onDestinationSelected,
          tabFor: tabFor,
          shellHeader: shellHeader,
          shellTopBar: shellTopBar,
          hideGlobalNav: hideGlobalNav,
          maskUnderPlayer: maskUnderPlayer,
        ),
    };
  }
}
