import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Controlled underline tab bar.
class Tabs extends StatelessWidget {
  const Tabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.scrollable = true,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return UnderlineTabBar(
      labels: labels,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      scrollable: scrollable,
    );
  }
}

/// Underline tab strip — brand/nav underline under the active label.
class UnderlineTabBar extends StatelessWidget {
  const UnderlineTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.scrollable = true,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) SizedBox(width: theme.spaceLg),
          _TabItem(
            label: labels[i],
            selected: i == selectedIndex,
            onTap: () => onChanged(i),
          ),
        ],
      ],
    );
    if (!scrollable) return row;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: row,
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: theme.spaceSm),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? theme.textPrimary : theme.textSecondary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: ShellTokens.shellNavUnderlineHeight,
              color: selected
                  ? ForjaShellColors.navUnderline
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
