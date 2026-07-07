import 'dart:io';
import 'package:flutter/material.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellNavRail extends StatelessWidget {
  const ShellNavRail({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isDesktop,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final topPadding = isDesktop && Platform.isMacOS
        ? ShellTokens.navRailLogoTopPaddingDesktopMac
        : ShellTokens.navRailLogoTopPaddingDefault;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
        child: IntrinsicHeight(
          child: NavigationRail(
            backgroundColor: Colors.transparent,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            indicatorColor: AppTheme.current.primaryColor,
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.white54,
            ),
            leading: Padding(
              padding: EdgeInsets.fromLTRB(0, topPadding, 0, ShellTokens.navRailLogoBottomPadding),
              child: Image.asset(
                AppTheme.isLightMode
                    ? 'assets/icon/logo-light.png'
                    : 'assets/icon/logo-dark.png',
                width: ShellTokens.navRailLogoWidth,
                fit: BoxFit.contain,
              ),
            ),
            destinations: visibleIds.map((id) {
              final dest = navDestinations[id]!;
              return NavigationRailDestination(
                icon: Icon(dest.icon, color: Colors.white54),
                selectedIcon: Icon(dest.activeIcon, color: Colors.white),
                label: Text(dest.label),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
