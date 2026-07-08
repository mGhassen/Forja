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
    final lightMode = AppTheme.isLightMode;
    final borderColor =
        lightMode ? ForjaShellColors.borderSubtle : Colors.white10;
    final selectedColor =
        lightMode ? ForjaShellColors.iconActive : Colors.white;
    final unselectedColor =
        lightMode ? ForjaShellColors.iconMuted : Colors.white54;

    return Container(
      height: ShellTokens.bottomNavHeight,
      decoration: BoxDecoration(
        color: lightMode ? AppTheme.appBackgroundLight : AppTheme.bgDark,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
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
                  child: Container(
                    width: ShellTokens.bottomNavItemWidth,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                          child: Icon(
                            isSelected ? dest.activeIcon : dest.icon,
                            color: isSelected ? selectedColor : unselectedColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dest.label,
                          style: TextStyle(
                            color: isSelected ? selectedColor : unselectedColor,
                            fontSize: ShellTokens.bottomNavLabelSize,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!lightMode)
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
                        (lightMode ? AppTheme.appBackgroundLight : AppTheme.bgDark)
                            .withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: lightMode ? ForjaShellColors.iconMuted : Colors.white24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
