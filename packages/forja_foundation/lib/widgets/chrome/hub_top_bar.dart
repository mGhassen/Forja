import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
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
    this.searchLabel,
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

  /// Required when [onSearch] is set and [searchBuilder] is null.
  final String? searchLabel;

  /// Required when [onCategories] is set — host owns the product string.
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
    assert(
      onCategories == null ||
          (categoriesLabel != null && categoriesLabel!.isNotEmpty),
      'HubTopBar: pass categoriesLabel when onCategories is set',
    );
    assert(
      onSearch == null ||
          searchBuilder != null ||
          (searchLabel != null && searchLabel!.isNotEmpty),
      'HubTopBar: pass searchLabel when onSearch is set without searchBuilder',
    );
    final search = onSearch == null
        ? null
        : (searchBuilder?.call(onSearch: onSearch!) ??
            _HubTab(
              label: searchLabel!,
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
              if (i > 0)
                SizedBox(
                  width: ShellPaintScope.usesTvDensityOf(context)
                      ? ShellTokens.hubTopBarItemGapTv
                      : ShellTokens.hubTopBarItemGap,
                ),
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
              label: categoriesLabel!,
              open: categoriesOpen,
              onTap: onCategories!,
            ) ??
            _HubTab(
              label: categoriesLabel!,
              selected: categoriesOpen,
              onTap: onCategories!,
            ));

    final tv = ShellPaintScope.usesTvDensityOf(context);
    final sectionGap = tv
        ? ShellTokens.hubTopBarSectionGapTv
        : ShellTokens.hubTopBarSectionGap;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: SizedBox(
          height: tv ? ShellTokens.homeTopBarHeightTv : ShellTokens.homeTopBarHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ShellTokens.compactChromeLeadingInset(context),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: sectionGap),
                ],
                if (search != null) ...[
                  search,
                  SizedBox(width: sectionGap),
                ],
                Expanded(child: menu),
                if (cats != null) ...[
                  SizedBox(width: sectionGap),
                  cats,
                ],
                if (trailing != null) ...[
                  SizedBox(width: sectionGap),
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ShellTokens.hubTopBarTabRadius),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tv
              ? ShellTokens.hubTopBarTabPadHTv
              : ShellTokens.hubTopBarTabPadH,
          vertical: tv
              ? ShellTokens.hubTopBarTabPadVTv
              : ShellTokens.hubTopBarTabPadV,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: tv
                ? ShellTokens.hubTopBarTabFontSizeTv
                : ShellTokens.hubTopBarTabFontSize,
          ),
        ),
      ),
    );
  }
}
