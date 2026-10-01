import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final pad = ShellTokens.chromeScale(10, tv: tv);
    final bottom = ShellTokens.chromeScale(12, tv: tv);
    return PlayerPopupListFocusScope(
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, bottom),
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
              padding: EdgeInsets.symmetric(
                vertical: ShellTokens.chromeScale(8, tv: tv),
              ),
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final pad = ShellTokens.chromeScale(6, tv: tv);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pad,
        pad,
        pad,
        ShellTokens.chromeScale(4, tv: tv),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: PlayerPopupTokens.muted,
          fontSize: tv ? ShellTokens.tvMetaFontSize : 11,
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
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  Widget _rowContent(bool hovered) {
    final input = (
      tvFocus: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
      mouseHover: ShellScope.inputPolicyOf(context).scaleOnHover,
    );
    final highlight = ShellInputPolicy.interactiveActive(
      ShellScope.inputPolicyOf(context),
      hovered: hovered,
      focused: _focused,
      context: context,
    );
    // Idle rows stay transparent (pre-wipe Sort menu); hover/selected = green fill.
    final bg = widget.selected || highlight
        ? PlayerPopupTokens.accentFill
        : Colors.transparent;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final pad = ShellTokens.chromeScale(10, tv: tv);
    final iconSize = ShellTokens.chromeScale(18, tv: tv);
    final gap = ShellTokens.chromeScale(10, tv: tv);
    final fontSize = tv ? ShellTokens.tvBodyFontSize : 13.0;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: input.tvFocus ? null : widget.onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: iconSize,
                color: widget.selected || highlight
                    ? PlayerPopupTokens.accent
                    : Colors.white.withValues(alpha: 0.75),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: widget.selected || highlight
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(
                  Icons.check_rounded,
                  size: iconSize,
                  color: PlayerPopupTokens.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = (
      tvFocus: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
      mouseHover: ShellScope.inputPolicyOf(context).scaleOnHover,
    );

    final row = MouseRegion(
      onEnter: input.mouseHover ? (_) => _setHovered(true) : null,
      onExit: input.mouseHover ? (_) => _setHovered(false) : null,
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) => _rowContent(_hoveredN.value),
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
        onHoverChange: input.mouseHover ? _setHovered : null,
        child: row,
      ),
    );
  }
}
