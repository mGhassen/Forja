import 'package:flutter/material.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellScaffold extends StatelessWidget {
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
  final bool hideGlobalNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.effectiveBackground),
          if (!AppTheme.isLightMode) ..._ambientGlows(context),
          Row(
            children: [
              if (useNavRail && !hideGlobalNav)
                ShellNavRail(
                  visibleIds: visibleIds,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  isDesktop: isDesktop,
                ),
              Expanded(
                child: Column(
                  children: [
                    ?shellHeader,
                    Expanded(
                      child: ShellBody(
                        selectedIndex: selectedIndex,
                        visibleIds: visibleIds,
                        mountedTabIds: mountedTabIds,
                        tabFor: tabFor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: useNavRail || hideGlobalNav
          ? null
          : ShellBottomNav(
              visibleIds: visibleIds,
              selectedIndex: selectedIndex,
              onItemTapped: onDestinationSelected,
            ),
    );
  }

  List<Widget> _ambientGlows(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return [
      Positioned(
        top: -80,
        right: -60,
        child: Container(
          width: ShellTokens.shellGlowTopRight,
          height: ShellTokens.shellGlowTopRight,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.current.primaryColor.withValues(alpha: 0.18),
                AppTheme.current.primaryColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 40,
        left: -80,
        child: Container(
          width: ShellTokens.shellGlowBottomLeft,
          height: ShellTokens.shellGlowBottomLeft,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.current.accentColor.withValues(alpha: 0.08),
                AppTheme.current.accentColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        top: height * 0.35,
        left: -40,
        child: Container(
          width: ShellTokens.shellGlowCenterLeft,
          height: ShellTokens.shellGlowCenterLeft,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.current.primaryColor.withValues(alpha: 0.10),
                AppTheme.current.primaryColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
