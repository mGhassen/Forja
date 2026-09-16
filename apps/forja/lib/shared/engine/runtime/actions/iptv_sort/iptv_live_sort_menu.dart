import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
              _IptvSortRow(
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
              _IptvSortRow(
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
}

class _IptvSortRow extends StatefulWidget {
  const _IptvSortRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_IptvSortRow> createState() => _IptvSortRowState();
}

class _IptvSortRowState extends State<_IptvSortRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final input = (
      tvFocus: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
      mouseHover: ShellScope.inputPolicyOf(context).scaleOnHover,
    );
    final highlight = _hovered || _focused;
    final chrome = playerPopupSelectChrome(
      selected: widget.selected,
      highlight: highlight,
    );

    final row = Material(
      color: chrome.bg,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: input.tvFocus ? null : widget.onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        // Hover is painted via [chrome.bg] — InkWell splash only.
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        onHover: input.mouseHover
            ? (h) {
                if (_hovered == h) return;
                setState(() => _hovered = h);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected || highlight
                    ? PlayerPopupTokens.accent
                    : Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: widget.selected || highlight
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected)
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

    final padded = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: row,
    );

    if (!input.tvFocus) return padded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FocusableControl(
        autoFocus: widget.selected &&
            PlayerPopupListFocusScope.claimAutofocus(context),
        onTap: widget.onTap,
        borderRadius: PlayerPopupTokens.cardRadius,
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        ensureVisibleMode: ShellPaintEnsureVisible.item,
        onFocusChange: (f) {
          if (_focused == f) return;
          setState(() => _focused = f);
        },
        onHoverChange: input.mouseHover
            ? (h) {
                if (_hovered == h) return;
                setState(() => _hovered = h);
              }
            : null,
        child: row,
      ),
    );
  }
}
