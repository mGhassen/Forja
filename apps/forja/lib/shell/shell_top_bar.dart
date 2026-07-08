import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({super.key});

  static const _categories = ['Films', 'TV Shows', 'Anime'];

  void _onCategoryTap(int index) {
    switch (index) {
      case 0:
        ShellBus.homeCategory.value = ShellHomeCategory.films;
        ShellBus.requestTab.value = 'home';
      case 1:
        ShellBus.homeCategory.value = ShellHomeCategory.tvShows;
        ShellBus.requestTab.value = 'home';
      case 2:
        ShellBus.requestTab.value = 'anime';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: ShellBus.homeScrollOffset,
      builder: (context, scrollOffset, _) {
        final bgOpacity = (scrollOffset / 24).clamp(0.0, 1.0);
        return ColoredBox(
          color: AppTheme.bgDark.withValues(alpha: bgOpacity),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: ShellTokens.shellTopBarHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ShellTokens.bodyHorizontalPadding,
                  ShellTokens.shellHeaderTopPadding,
                  ShellTokens.bodyHorizontalPadding,
                  0,
                ),
                child: ValueListenableBuilder<ShellHomeCategory>(
                  valueListenable: ShellBus.homeCategory,
                  builder: (context, selectedCategory, _) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...List.generate(_categories.length, (index) {
                          final label = _categories[index];
                          final isActive = switch (index) {
                            0 => selectedCategory == ShellHomeCategory.films,
                            1 => selectedCategory == ShellHomeCategory.tvShows,
                            _ => false,
                          };
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < _categories.length - 1 ? 36 : 0,
                            ),
                            child: _CategoryTab(
                              label: label,
                              isActive: isActive,
                              onTap: () => _onCategoryTap(index),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;

    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1,
      pressScale: 1,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: ShellTokens.navRailLogoHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          SizedBox(height: ShellTokens.shellCategoryUnderlineGap),
          AnimatedContainer(
            duration: ShellTokens.navSelectionAnimation,
            height: ShellTokens.shellNavUnderlineHeight,
            width: isActive ? 28 : 0,
            decoration: BoxDecoration(
              color: isActive ? ForjaShellColors.navUnderline : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
