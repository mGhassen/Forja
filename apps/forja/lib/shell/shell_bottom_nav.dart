import 'dart:ui';
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

    Widget navContent = Container(
      height: ShellTokens.bottomNavHeight,
      decoration: BoxDecoration(
        color: AppTheme.current.bgDark.withValues(alpha: lightMode ? 1.0 : 0.75),
        border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
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
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dest.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
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
                        AppTheme.current.bgDark.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );

    if (lightMode) {
      return ClipRect(child: navContent);
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: navContent,
      ),
    );
  }
}
