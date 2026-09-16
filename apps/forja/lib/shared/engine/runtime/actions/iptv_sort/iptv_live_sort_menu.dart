import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Exact pre-wipe IPTV Sort popup — Categories + Channels sections.
class IptvLiveSortMenu extends StatefulWidget {
  const IptvLiveSortMenu({
    super.key,
    required this.categorySort,
    required this.contentSort,
    required this.onCategorySort,
    required this.onContentSort,
  });

  final PortalCatalogSort categorySort;
  final PortalCatalogSort contentSort;
  final ValueChanged<PortalCatalogSort> onCategorySort;
  final ValueChanged<PortalCatalogSort> onContentSort;

  @override
  State<IptvLiveSortMenu> createState() => _IptvLiveSortMenuState();
}

class _IptvLiveSortMenuState extends State<IptvLiveSortMenu> {
  static const _options = <(PortalCatalogSort, String, IconData)>[
    (
      PortalCatalogSort.playlist,
      'Playlist Order',
      Icons.format_list_numbered_rounded,
    ),
    (PortalCatalogSort.nameAsc, 'Name (A–Z)', Icons.sort_by_alpha_rounded),
    (PortalCatalogSort.nameDesc, 'Name (Z–A)', Icons.sort_by_alpha_rounded),
  ];

  late PortalCatalogSort _categorySort = widget.categorySort;
  late PortalCatalogSort _contentSort = widget.contentSort;

  @override
  void didUpdateWidget(covariant IptvLiveSortMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categorySort != widget.categorySort) {
      _categorySort = widget.categorySort;
    }
    if (oldWidget.contentSort != widget.contentSort) {
      _contentSort = widget.contentSort;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlayerPopupListFocusScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel('Categories'),
            for (final (sort, label, icon) in _options)
              _sortRow(
                icon: icon,
                label: label,
                selected: _categorySort == sort,
                onTap: () {
                  setState(() => _categorySort = sort);
                  widget.onCategorySort(sort);
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: PlayerPopupTokens.border),
            ),
            _sectionLabel('Channels'),
            for (final (sort, label, icon) in _options)
              _sortRow(
                icon: icon,
                label: label,
                selected: _contentSort == sort,
                onTap: () {
                  setState(() => _contentSort = sort);
                  widget.onContentSort(sort);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: PlayerPopupTokens.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _sortRow({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final row = Material(
      color: selected ? PlayerPopupTokens.accentFill : Colors.transparent,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? PlayerPopupTokens.accent
                    : Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: PlayerPopupTokens.accent,
                ),
            ],
          ),
        ),
      ),
    );
    if (!tvFocus) {
      return Padding(padding: const EdgeInsets.only(bottom: 4), child: row);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FocusableControl(
        autoFocus:
            selected && PlayerPopupListFocusScope.claimAutofocus(context),
        onTap: onTap,
        borderRadius: PlayerPopupTokens.cardRadius,
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        ensureVisibleMode: ShellPaintEnsureVisible.item,
        child: row,
      ),
    );
  }
}
