import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({super.key});

  static const _categories = ['Films', 'TV Shows', 'Anime'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ShellTokens.shellTopBarHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              AppTheme.isLightMode
                  ? 'assets/icon/logo-light.png'
                  : 'assets/icon/logo-dark.png',
              width: ShellTokens.shellLogoWidth,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 40),
            ...List.generate(_categories.length, (index) {
              final label = _categories[index];
              final isActive = index == 0;
              return Padding(
                padding: EdgeInsets.only(right: index < _categories.length - 1 ? 36 : 0),
                child: _CategoryTab(label: label, isActive: isActive),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: color,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: ShellTokens.navSelectionAnimation,
          height: ShellTokens.shellNavUnderlineHeight,
          width: isActive ? 28 : 0,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.current.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
