import 'package:flutter/material.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

class ShellBottomNav extends StatelessWidget {
  const ShellBottomNav({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ShellTokens.bottomNavHeight,
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: visibleIds.asMap().entries.map((entry) {
                final idx = entry.key;
                final id = entry.value;
                final dest = navDestinations[id]!;
                final isSelected = selectedIndex == idx;

                return InkWell(
                  hoverColor: ForjaShellColors.inkHover,
                  splashColor: ForjaShellColors.inkSplash,
                  onTap: () => onItemTapped(idx),
                  child: SizedBox(
                    width: ShellTokens.bottomNavItemWidth,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: ShellTokens.navSelectionAnimation,
                            padding: const EdgeInsets.symmetric(
                              horizontal: ShellTokens.bottomNavIconPaddingH,
                              vertical: ShellTokens.bottomNavIconPaddingV,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ForjaShellColors.chipSelectedBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(ShellTokens.navSelectionBorderRadius),
                            ),
                            child: NavDestinationIcon(
                              destination: dest,
                              selected: isSelected,
                              color: isSelected ? Colors.white : Colors.white54,
                              size: ShellTokens.navRailIconSize,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dest.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white54,
                              fontSize: ShellTokens.bottomNavLabelSize,
                              height: 1,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: ShellTokens.bottomNavFadeWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      AppTheme.bgDark.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}