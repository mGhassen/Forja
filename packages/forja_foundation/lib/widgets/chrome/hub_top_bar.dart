import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pack-driven hub chrome paint over hero — Search + menus + Categories.
///
/// Host owns ValueNotifiers, TV focus nodes, and filter registry.
class HubTopBar extends StatelessWidget {
  const HubTopBar({
    super.key,
    required this.menus,
    required this.selectedMenuId,
    required this.onMenuSelected,
    this.onSearch,
    this.categoriesLabel,
    this.onCategories,
    this.categoriesOpen = false,
    this.opacity = 1,
    this.translateY = 0,
    this.leading,
    this.trailing,
    this.menuBuilder,
    this.searchBuilder,
    this.categoriesBuilder,
  });

  final List<({String id, String label})> menus;
  final String? selectedMenuId;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback? onSearch;
  final String? categoriesLabel;
  final VoidCallback? onCategories;
  final bool categoriesOpen;
  final double opacity;
  final double translateY;
  final Widget? leading;
  final Widget? trailing;

  final Widget Function({
    required List<({String id, String label})> menus,
    required String? selectedMenuId,
    required ValueChanged<String> onSelect,
  })? menuBuilder;

  final Widget Function({required VoidCallback onSearch})? searchBuilder;
  final Widget Function({
    required String label,
    required bool open,
    required VoidCallback onTap,
  })? categoriesBuilder;

  @override
  Widget build(BuildContext context) {
    final search = onSearch == null
        ? null
        : (searchBuilder?.call(onSearch: onSearch!) ??
            _HubTab(
              label: 'Search',
              selected: false,
              onTap: onSearch!,
            ));

    final menu = menuBuilder?.call(
          menus: menus,
          selectedMenuId: selectedMenuId,
          onSelect: onMenuSelected,
        ) ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < menus.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _HubTab(
                label: menus[i].label,
                selected: selectedMenuId == menus[i].id,
                onTap: () => onMenuSelected(menus[i].id),
              ),
            ],
          ],
        );

    final cats = onCategories == null
        ? null
        : (categoriesBuilder?.call(
              label: categoriesLabel ?? 'Categories',
              open: categoriesOpen,
              onTap: onCategories!,
            ) ??
            _HubTab(
              label: categoriesLabel ?? 'Categories',
              selected: categoriesOpen,
              onTap: onCategories!,
            ));

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: SizedBox(
          height: ShellTokens.homeTopBarHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ShellTokens.compactChromeLeadingInset(context),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                if (search != null) ...[
                  search,
                  const SizedBox(width: 12),
                ],
                Expanded(child: menu),
                if (cats != null) ...[
                  const SizedBox(width: 12),
                  cats,
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubTab extends StatelessWidget {
  const _HubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
