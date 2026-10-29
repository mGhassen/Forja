import 'package:flutter/material.dart';
import 'package:forja/shell/frame/shell_scaffold.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Touch shell: bottom bar on phones in both orientations; side rail on
/// tablets in landscape.
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

  /// Landscape tablets get the side rail; phones (either orientation) and
  /// portrait tablets keep the bottom bar.
  static bool usesNavRail(Size size) =>
      size.width > size.height &&
      size.shortestSide >= ShellTokens.mobileNavRailMinShortestSide;

  @override
  Widget build(BuildContext context) {
    // Keep landscape rail mounted while Offstage (IPTV) — do not tie
    // useNavRail to hideGlobalNav or exit remounts the rail.
    final useNavRail = usesNavRail(MediaQuery.sizeOf(context));

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
      maskUnderPlayer: maskUnderPlayer,
    );
  }
}
