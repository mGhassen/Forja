import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({super.key});

  static const _categories = ['Films', 'TV Shows', 'Anime'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_categories.length, (index) {
                final label = _categories[index];
                final isActive = index == 0;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _categories.length - 1 ? 36 : 0,
                  ),
                  child: _CategoryTab(label: label, isActive: isActive),
                );
              }),
            ],
          ),
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
    );
  }
}
