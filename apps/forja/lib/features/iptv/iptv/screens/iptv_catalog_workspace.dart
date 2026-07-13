import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/iptv_portal_share.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';

/// Colored Live / Movies / Series shelf — same hues as the old section tiles.
class _IptvSectionShelfSpec {
  const _IptvSectionShelfSpec({
    required this.section,
    required this.label,
    required this.icon,
    required this.colors,
  });

  final IptvSection section;
  final String label;
  final IconData icon;
  final List<Color> colors;

  /// Compact shelf pill — solid vibrant accent (tile gradients are too dark).
  Color get shelfAccent => section == IptvSection.series
      ? colors.last
      : colors.first;
}

const _kSectionShelf = <_IptvSectionShelfSpec>[
  _IptvSectionShelfSpec(
    section: IptvSection.live,
    label: 'Live',
    icon: Icons.live_tv_rounded,
    colors: [Color(0xFFEF4444), Color(0xFF7C2D12)],
  ),
  _IptvSectionShelfSpec(
    section: IptvSection.vod,
    label: 'Movies',
    icon: Icons.movie_rounded,
    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ),
  _IptvSectionShelfSpec(
    section: IptvSection.series,
    label: 'Series',
    icon: Icons.video_library_rounded,
    colors: [Color(0xFF374151), Color(0xFF1CE783)],
  ),
];

const _kShelfTabHeight = 36.0;
const _kShelfTabRadius = 8.0;
const _kSearchCollapsed = 40.0;
const _kSearchExpanded = 260.0;

/// Top bar: solid shelf tabs left · expanding search + portal right.
class IptvCatalogTopBar extends StatefulWidget {
  const IptvCatalogTopBar({
    super.key,
    required this.ctrl,
    required this.onTogglePanel,
    required this.onSection,
  });

  final IptvController ctrl;
  final VoidCallback onTogglePanel;
  final ValueChanged<IptvSection> onSection;

  @override
  State<IptvCatalogTopBar> createState() => _IptvCatalogTopBarState();
}

class _IptvCatalogTopBarState extends State<IptvCatalogTopBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final AnimationController _searchAnim;
  late final Animation<double> _searchExpand;
  bool _searchDialogOpen = false;
  bool _searchToolFocused = false;
  bool _searchToolHovered = false;
  bool _portalToolFocused = false;
  bool _portalToolHovered = false;

  IptvController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ctrl.browserSearch;
    _searchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _searchExpand = CurvedAnimation(
      parent: _searchAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (ctrl.browserSearchOpen) {
      _searchAnim.value = 1;
    }
    ctrl.addListener(_onCtrl);
  }

  @override
  void dispose() {
    ctrl.removeListener(_onCtrl);
    _searchAnim.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (!mounted) return;
    if (ctrl.activePortal == null && ctrl.browserSearchOpen) {
      _closeSearch();
    }
    final open = ctrl.browserSearchOpen;
    if (open && _searchAnim.status != AnimationStatus.completed) {
      _searchAnim.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    } else if (!open && _searchAnim.status != AnimationStatus.dismissed) {
      _searchAnim.reverse();
      _searchCtrl.clear();
      _searchFocus.unfocus();
    }
    setState(() {});
  }

  String get _portalLabel {
    final p = ctrl.activePortal;
    if (p == null) return 'Portals';
    final n = p.name.trim();
    if (n.isNotEmpty) return n;
    return p.portal.url;
  }

  void _focusDownFromShelf() {
    iptvFocusCatalogGroupRow(ctrl.browserCategoryFocusIndex);
  }

  void _focusDownFromTopTools() {
    iptvFocusCatalogGroupRow(ctrl.browserCategoryFocusIndex);
  }

  void _focusDownFromPortalTool() {
    if (ctrl.portalPanelOpen) {
      iptvFocusRowItem('iptv-portal-header', 2);
    } else {
      iptvFocusCatalogGroupRow(ctrl.browserCategoryFocusIndex);
    }
  }

  Future<void> _openSearch(
    BuildContext context, {
    required bool compact,
  }) async {
    if (!compact) {
      if (ctrl.browserSearchOpen) return;
      ctrl.openBrowserSearch();
      return;
    }

    if (_searchDialogOpen) {
      _searchFocus.requestFocus();
      return;
    }

    _searchCtrl.text = ctrl.browserSearch;
    ctrl.openBrowserSearch();
    _searchDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => ShellScope.rehost(
        context,
        _IptvCatalogSearchDialog(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: ctrl.setBrowserSearch,
          onClear: _clearSearchQuery,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
    _searchDialogOpen = false;
    if (mounted && ctrl.browserSearchOpen) {
      _closeSearch();
    }
  }

  void _closeSearch() {
    ctrl.closeBrowserSearch();
  }

  void _clearSearchQuery() {
    _searchCtrl.clear();
    ctrl.setBrowserSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final hasActivePortal = ctrl.activePortal != null;
    if (!hasActivePortal) {
      iptvSyncRow(rowId: 'iptv-sections', sortOrder: 0, itemCount: 0);
      iptvSyncRow(rowId: 'iptv-section-reload', sortOrder: 0, itemCount: 0);
      iptvSyncRow(rowId: 'iptv-top-tools', sortOrder: 1, itemCount: 0);
      return const SizedBox.shrink();
    }

    iptvSyncRow(
      rowId: 'iptv-sections',
      sortOrder: 0,
      itemCount: _kSectionShelf.length,
    );
    iptvSyncRow(
      rowId: 'iptv-section-reload',
      sortOrder: 0,
      itemCount: _kSectionShelf.length,
    );
    iptvSyncRow(rowId: 'iptv-top-tools', sortOrder: 1, itemCount: 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final leftPadding = ShellTokens.compactChromeLeadingInset(
          context,
        ).clamp(ShellTokens.bodyHorizontalPadding, constraints.maxWidth * 0.28);

        return Padding(
          padding: EdgeInsets.fromLTRB(leftPadding, 10, 12, 8),
          child: Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildShelf(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              compact
                  ? _buildSearchIcon(context, compact: true)
                  : _buildExpandingSearch(context),
              const SizedBox(width: 8),
              _buildPortalButton(context, compact: compact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShelf(BuildContext context) {
    return Container(
      height: _kShelfTabHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_kShelfTabRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _kSectionShelf.length; i++)
            _IptvSectionShelfTab(
              spec: _kSectionShelf[i],
              selected: ctrl.activeSection == _kSectionShelf[i].section,
              listIndex: i,
              isFirst: i == 0,
              isLast: i == _kSectionShelf.length - 1,
              onTap: () => widget.onSection(_kSectionShelf[i].section),
              onReload: () => ctrl.reloadSection(_kSectionShelf[i].section),
              onDownEdge: _focusDownFromShelf,
              onRightEdge: i == _kSectionShelf.length - 1
                  ? () => iptvFocusRowItem('iptv-top-tools', 0)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildExpandingSearch(BuildContext context) {
    return AnimatedBuilder(
      animation: _searchExpand,
      builder: (context, _) {
        final t = _searchExpand.value;
        final width =
            _kSearchCollapsed + (_kSearchExpanded - _kSearchCollapsed) * t;

        // Field lays out at full width; ClipRect reveals it as the shell expands.
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            height: _kSearchCollapsed,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerRight,
                clipBehavior: Clip.hardEdge,
                children: [
                  Opacity(
                    opacity: t,
                    child: IgnorePointer(
                      ignoring: t < 0.55,
                      child: OverflowBox(
                        maxWidth: _kSearchExpanded,
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: _kSearchExpanded,
                          child: _buildSearchField(context),
                        ),
                      ),
                    ),
                  ),
                  if (t < 0.95)
                    Opacity(
                      opacity: (1.0 - t * 1.4).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: t > 0.2,
                        child: _buildSearchIcon(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchIcon(BuildContext context, {bool compact = false}) {
    final active = iptvFocusActive(
      context,
      hovered: _searchToolHovered,
      focused: _searchToolFocused,
    );
    final tvFocused = iptvTvFocused(context, focused: _searchToolFocused);
    return iptvTap(
      context: context,
      onTap: () => _openSearch(context, compact: compact),
      borderRadius: _kSearchCollapsed / 2,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 0,
      onDownEdge: _focusDownFromTopTools,
      onLeftEdge: () =>
          iptvFocusRowItem('iptv-sections', _kSectionShelf.length - 1),
      onRightEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
      onFocusChange: (focused) => setState(() => _searchToolFocused = focused),
      onHoverChange: (hovered) => setState(() => _searchToolHovered = hovered),
      child: Container(
        width: _kSearchCollapsed,
        height: _kSearchCollapsed,
        decoration: BoxDecoration(
          color: iptvFocusSurfaceColor(
            active: active,
            tvFocused: tvFocused,
            idleAlpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
          border: Border.all(
            color: iptvFocusOutlineColor(
              active: active,
              tvFocused: tvFocused,
              idleAlpha: 0.12,
              hoverAlpha: 0.22,
            ),
            width: tvFocused ? 1.5 : 1,
          ),
        ),
        child: Icon(
          Icons.search_rounded,
          color: iptvFocusFg(
            Colors.white60,
            active: active,
            tvFocused: tvFocused,
          ),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: _kSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TvBrowseTextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: ctrl.setBrowserSearch,
              onEscape: _closeSearch,
              browsePlaceholder: 'Search…',
              browseHintStyle: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
              caretHeight: 16,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          iptvTap(
            context: context,
            onTap: _closeSearch,
            borderRadius: 16,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalButton(BuildContext context, {bool compact = false}) {
    final selected = ctrl.portalPanelOpen;
    final hasPortal = ctrl.activePortal != null;
    final active = iptvFocusActive(
      context,
      hovered: _portalToolHovered,
      focused: _portalToolFocused,
    );
    final tvFocused = iptvTvFocused(context, focused: _portalToolFocused);
    final showHighlight = selected || active;
    return iptvTap(
      context: context,
      onTap: widget.onTogglePanel,
      borderRadius: _kShelfTabRadius,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 1,
      onDownEdge: _focusDownFromPortalTool,
      onLeftEdge: () => iptvFocusRowItem('iptv-top-tools', 0),
      onRightEdge: selected
          ? () => iptvFocusRowItem('portals', 0)
          : null,
      onFocusChange: (focused) => setState(() => _portalToolFocused = focused),
      onHoverChange: (hovered) => setState(() => _portalToolHovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: _kShelfTabHeight,
        constraints: BoxConstraints(maxWidth: compact ? 44 : 180),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: tvFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
              : showHighlight
                  ? Colors.white.withValues(alpha: selected ? 0.14 : 0.10)
                  : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(_kShelfTabRadius),
          border: Border.all(
            color: tvFocused
                ? ForjaShellColors.brandGreen
                : !hasPortal
                    ? IptvShellStyle.accent.withValues(alpha: 0.65)
                    : Colors.white
                        .withValues(alpha: showHighlight ? 0.28 : 0.10),
            width: tvFocused ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPortal ? Icons.dns_rounded : Icons.add_link_rounded,
              size: 16,
              color: hasPortal
                  ? iptvFocusFg(
                      Colors.white,
                      active: active,
                      tvFocused: tvFocused,
                    )
                  : iptvFocusFg(
                      IptvShellStyle.accent,
                      active: active,
                      tvFocused: tvFocused,
                    ),
            ),
            if (!compact) ...[
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _portalLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: iptvFocusFg(
                      Colors.white,
                      active: active,
                      tvFocused: tvFocused,
                    ),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                selected
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: iptvFocusFg(
                  Colors.white60,
                  active: active,
                  tvFocused: tvFocused,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IptvCatalogSearchDialog extends StatefulWidget {
  const _IptvCatalogSearchDialog({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  State<_IptvCatalogSearchDialog> createState() =>
      _IptvCatalogSearchDialogState();
}

class _IptvCatalogSearchDialogState extends State<_IptvCatalogSearchDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: IptvShellStyle.dialogSurface(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Search IPTV',
                        style: IptvShellStyle.overlayTitle,
                      ),
                    ),
                    iptvCloseButton(context, onTap: widget.onClose),
                  ],
                ),
                const SizedBox(height: 14),
                TvBrowseTextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: widget.onChanged,
                  onEscape: widget.onClose,
                  browsePlaceholder: 'Search channels or categories…',
                  browseHintStyle: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  caretHeight: 18,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search channels or categories…',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    suffixIcon: widget.controller.text.isEmpty
                        ? null
                        : iptvCloseButton(context, onTap: widget.onClear),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: IptvShellStyle.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: IptvShellStyle.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: IptvShellStyle.accent,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shelf tab — solid section accent when selected.
/// Hover/focus expands right to reveal a catalog reload control.
class _IptvSectionShelfTab extends StatefulWidget {
  const _IptvSectionShelfTab({
    required this.spec,
    required this.selected,
    required this.listIndex,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onReload,
    this.onDownEdge,
    this.onRightEdge,
  });

  final _IptvSectionShelfSpec spec;
  final bool selected;
  final int listIndex;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onReload;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_IptvSectionShelfTab> createState() => _IptvSectionShelfTabState();
}

class _IptvSectionShelfTabState extends State<_IptvSectionShelfTab> {
  bool _hover = false;
  bool _focused = false;

  bool get _tv => iptvUseTvFocus(context);

  bool get _revealReload => _hover || (_focused && !_tv);

  BorderRadius get _radius {
    final r = Radius.circular(_kShelfTabRadius - 1);
    if (widget.isFirst && widget.isLast) return BorderRadius.all(r);
    if (widget.isFirst) {
      return BorderRadius.only(topLeft: r, bottomLeft: r);
    }
    if (widget.isLast) {
      return BorderRadius.only(topRight: r, bottomRight: r);
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    final showColor = widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: _kShelfTabHeight,
        decoration: BoxDecoration(
          color: showColor ? widget.spec.shelfAccent : Colors.transparent,
          borderRadius: _radius,
          boxShadow: widget.selected && showColor
              ? [
                  BoxShadow(
                    color: widget.spec.shelfAccent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iptvTap(
              context: context,
              onTap: widget.onTap,
              borderRadius: _kShelfTabRadius,
              scaleOnFocus: 1.0,
              suppressInkHover: true,
              tvZone: ShellTvZone.topBar,
              tvRowId: 'iptv-sections',
              listIndex: widget.listIndex,
              tvItemIndex: widget.listIndex,
              onDownEdge: widget.onDownEdge,
              onRightEdge: _revealReload
                  ? () => iptvFocusRowItem(
                      'iptv-section-reload',
                      widget.listIndex,
                    )
                  : widget.onRightEdge,
              onLeftEdge: widget.listIndex == 0
                  ? null
                  : () =>
                        iptvFocusRowItem('iptv-sections', widget.listIndex - 1),
              onFocusChange: (f) => setState(() => _focused = f),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.spec.icon,
                      size: 16,
                      color: showColor ? Colors.white : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.spec.label,
                      style: GoogleFonts.inter(
                        color: showColor ? Colors.white : Colors.white60,
                        fontSize: 12.5,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: _revealReload ? 1 : 0,
                child: iptvTap(
                  context: context,
                  onTap: widget.onReload,
                  borderRadius: 8,
                  scaleOnFocus: 1.0,
                  suppressInkHover: true,
                  tvZone: ShellTvZone.topBar,
                  tvRowId: 'iptv-section-reload',
                  listIndex: widget.listIndex,
                  tvItemIndex: widget.listIndex,
                  onLeftEdge: () =>
                      iptvFocusRowItem('iptv-sections', widget.listIndex),
                  onRightEdge: widget.onRightEdge,
                  onDownEdge: widget.onDownEdge,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: 'Reload catalog',
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: showColor || _revealReload
                            ? Colors.white.withValues(alpha: 0.95)
                            : Colors.white60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IptvPortalPanel extends StatefulWidget {
  const IptvPortalPanel({
    super.key,
    required this.ctrl,
    required this.width,
    required this.onClose,
  });

  final IptvController ctrl;
  final double width;
  final VoidCallback onClose;

  @override
  State<IptvPortalPanel> createState() => _IptvPortalPanelState();
}

class _IptvPortalPanelState extends State<IptvPortalPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _panelFocus = FocusNode();
  String _query = '';
  bool _searchOpen = false;
  bool _didFocusHeaderOnOpen = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrlChanged);
    if (widget.ctrl.portalPanelOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPanelHeader());
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    if (widget.ctrl.portalPanelOpen) {
      if (!_didFocusHeaderOnOpen && !_searchOpen) {
        _didFocusHeaderOnOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _focusPanelHeader());
      }
    } else {
      _didFocusHeaderOnOpen = false;
    }
  }

  void _focusPanelHeader() {
    if (!mounted || !widget.ctrl.portalPanelOpen || _searchOpen) return;
    iptvFocusRowItem('iptv-portal-header', 2);
  }

  void _openSearch() {
    if (_searchOpen) {
      _searchFocus.requestFocus();
      return;
    }
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_searchOpen && _query.isEmpty) return;
    _searchCtrl.clear();
    setState(() {
      _searchOpen = false;
      _query = '';
    });
    _searchFocus.unfocus();
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  List<VerifiedPortal> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.ctrl.verified;
    return widget.ctrl.verified.where((v) {
      return v.name.toLowerCase().contains(q) ||
          v.portal.url.toLowerCase().contains(q) ||
          v.portal.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final list = _filtered;
    final activeKey = ctrl.activePortal?.key;

    return Focus(
      focusNode: _panelFocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          if (_searchOpen) {
            _closeSearch();
            return KeyEventResult.handled;
          }
          widget.onClose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!iptvFocusBrowserCategories(ctrl)) {
              iptvFocusRowItem('browser-streams', 0);
            }
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: IptvShellStyle.surface,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: _searchOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TvBrowseTextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: (v) => setState(() => _query = v),
                      onEscape: _closeSearch,
                      browsePlaceholder: 'Search portals…',
                      browseHintStyle: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      caretHeight: 18,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search portals…',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : iptvCloseButton(
                                context,
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                  _searchFocus.requestFocus();
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  ctrl.statusText.isEmpty
                      ? '${list.length} portal${list.length == 1 ? '' : 's'}'
                      : ctrl.statusText,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? _buildEmpty()
                    : _buildPortalList(list, activeKey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ctrl = widget.ctrl;
    iptvSyncRow(rowId: 'iptv-portal-header', sortOrder: 0, itemCount: 3);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Portals',
            style: IptvShellStyle.headerTitle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          IptvIconAction(
            tooltip: _searchOpen ? 'Close search' : 'Search portals',
            onPressed: _toggleSearch,
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            color: _searchOpen ? IptvShellStyle.accent : null,
            tvRowId: 'iptv-portal-header',
            tvItemIndex: 0,
            tvZone: ShellTvZone.topBar,
            onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
            onDownEdge: () => iptvFocusRowItem('portals', 0),
            onRightEdge: () => iptvFocusRowItem('iptv-portal-header', 1),
          ),
          IptvIconAction(
            tooltip: ctrl.isScraping ? 'Stop scrape' : 'Scrape portals',
            onPressed: ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
            icon: ctrl.isScraping
                ? Icons.stop_circle_rounded
                : Icons.travel_explore_rounded,
            color: ctrl.isScraping ? IptvShellStyle.accent : null,
            tvRowId: 'iptv-portal-header',
            tvItemIndex: 1,
            tvZone: ShellTvZone.topBar,
            onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
            onDownEdge: () => iptvFocusRowItem('portals', 0),
            onLeftEdge: () => iptvFocusRowItem('iptv-portal-header', 0),
            onRightEdge: () => iptvFocusRowItem('iptv-portal-header', 2),
          ),
          IptvIconAction(
            tooltip: 'Add portal',
            onPressed: () => _showAddDialog(context),
            icon: Icons.add_rounded,
            tvRowId: 'iptv-portal-header',
            tvItemIndex: 2,
            tvZone: ShellTvZone.topBar,
            onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
            onDownEdge: () => iptvFocusRowItem('portals', 0),
            onLeftEdge: () => iptvFocusRowItem('iptv-portal-header', 1),
          ),
          iptvCloseButton(context, onTap: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt_rounded,
              size: 48,
              color: IptvShellStyle.accent,
            ),
            const SizedBox(height: 12),
            Text('No portals yet', style: IptvShellStyle.headerTitle),
            const SizedBox(height: 8),
            Text(
              'Scrape or add a portal to browse channels.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalList(List<VerifiedPortal> list, String? activeKey) {
    final ctrl = widget.ctrl;
    iptvSyncRow(
      rowId: 'portals',
      sortOrder: 2,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final v = list[i];
        return _PortalHoverTile(
          portal: v,
          ctrl: ctrl,
          isActive: v.key == activeKey,
          listIndex: i,
          onUpEdge: i == 0
              ? () => iptvFocusRowItem('iptv-portal-header', 2)
              : null,
          onEdit: () => _showPortalDialog(context, existing: v),
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context) =>
      _showPortalDialog(context);

  Future<void> _showPortalDialog(
    BuildContext context, {
    VerifiedPortal? existing,
  }) {
    widget.ctrl.addError = null;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ShellScope.rehost(
        context,
        _PortalFormDialog(ctrl: widget.ctrl, existing: existing),
      ),
    );
  }
}

class _PortalExpiryTone {
  const _PortalExpiryTone({required this.color, required this.label});

  final Color color;
  final String label;
}

const _expiryMonthIndex = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

DateTime? _parsePortalExpiryDate(String expiry) {
  final s = expiry.trim();
  if (s.isEmpty || s.toLowerCase() == 'unknown') return null;

  final ts = int.tryParse(s);
  if (ts != null) {
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  final parts = s.split(RegExp(r'\s+'));
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = _expiryMonthIndex[parts[1].toLowerCase()];
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

_PortalExpiryTone _portalExpiryTone(String expiry) {
  final label = expiry.trim().isEmpty ? 'Unknown' : expiry.trim();
  final end = _parsePortalExpiryDate(label);
  if (end == null) {
    return _PortalExpiryTone(
      color: const Color(0xFF9CA3AF),
      label: label == 'Unknown' ? 'Ends: Unknown' : 'Ends: $label',
    );
  }

  final today = DateTime.now();
  final midnightToday = DateTime(today.year, today.month, today.day);
  final days = end.difference(midnightToday).inDays;

  final Color color;
  if (days < 0) {
    color = const Color(0xFFEF4444);
  } else if (days <= 7) {
    color = const Color(0xFFF59E0B);
  } else if (days <= 30) {
    color = const Color(0xFFEAB308);
  } else {
    color = const Color(0xFF22C55E);
  }

  final prefix = days < 0 ? 'Expired' : 'Ends';
  return _PortalExpiryTone(color: color, label: '$prefix $label');
}

class _PortalFormDialog extends StatefulWidget {
  const _PortalFormDialog({required this.ctrl, this.existing});

  final IptvController ctrl;
  final VerifiedPortal? existing;

  @override
  State<_PortalFormDialog> createState() => _PortalFormDialogState();
}

class _PortalFormDialogState extends State<_PortalFormDialog> {
  static const _codeLen = IptvPortalShare.shareCodeLength;
  static const _portalDialogRowId = 'iptv-portal-dialog';

  bool get _tv => iptvUseTvFocus(context);

  bool get _compact => !_tv;

  bool get _dense => _tv || _compact;

  double get _codeBoxWidth => _tv ? 28.0 : (_compact ? 30.0 : 38.0);

  double get _codeBoxHeight => _tv ? 42.0 : (_compact ? 52.0 : 76.0);

  double get _codeFontSize => _tv ? 17.0 : (_compact ? 20.0 : 26.0);

  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _pasteCtrl;
  late final FocusNode _pasteFocus;
  late final FocusNode _urlFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  late final FocusNode _expandFocus;
  late final FocusNode _submitFocus;
  late final FocusNode _cancelFocus;
  FocusOnKeyEventCallback? _pasteKeyHandler;
  bool _obscurePassword = true;
  bool _importingShareCode = false;
  bool _showManualForm = false;
  String? _shareCodeError;
  String? _lastImportedCode;
  bool _expandFocused = false;
  bool _pasteEditing = false;

  bool get _editing => widget.existing != null;

  ShellTvFocusMeta get _pasteTvMeta => const ShellTvFocusMeta(
        tabId: 'iptv',
        zone: ShellTvZone.row,
        rowId: _portalDialogRowId,
        itemIndex: 0,
      );

  void _registerPasteTvNode() {
    if (!iptvUseTvFocus(context)) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: 'iptv',
      rowId: _portalDialogRowId,
      index: 0,
      node: _pasteFocus,
    );
  }

  void _unregisterPasteTvNode() {
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: 'iptv',
      rowId: _portalDialogRowId,
      index: 0,
      node: _pasteFocus,
    );
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _urlCtrl = TextEditingController(text: e?.portal.url ?? '');
    _userCtrl = TextEditingController(text: e?.portal.username ?? '');
    _passCtrl = TextEditingController(text: e?.portal.password ?? '');
    _pasteCtrl = TextEditingController();
    _pasteFocus = FocusNode(debugLabel: 'iptv-share-paste');
    _urlFocus = FocusNode(debugLabel: 'iptv-portal-url');
    _userFocus = FocusNode(debugLabel: 'iptv-portal-user');
    _passFocus = FocusNode(debugLabel: 'iptv-portal-pass');
    _expandFocus = FocusNode(debugLabel: 'iptv-portal-expand');
    _submitFocus = FocusNode(debugLabel: 'iptv-portal-submit');
    _cancelFocus = FocusNode(debugLabel: 'iptv-portal-cancel');
    if (_editing) _showManualForm = true;
    _pasteKeyHandler = _pasteFocus.onKeyEvent;
    _pasteFocus.onKeyEvent = _handlePasteKey;
    _pasteFocus.addListener(() {
      if (!_pasteFocus.hasFocus && _pasteEditing && mounted) {
        setState(() => _pasteEditing = false);
      }
      if (mounted) setState(() {});
    });
    _pasteCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerPasteTvNode();
      if (iptvUseTvFocus(context)) {
        if (_editing) {
          _urlFocus.requestFocus();
        } else {
          _focusDialogItem(1);
        }
      } else if (_editing) {
        _urlFocus.requestFocus();
      } else {
        _pasteFocus.requestFocus();
      }
    });
  }

  KeyEventResult _handlePasteKey(FocusNode node, KeyEvent event) {
    if (mounted && iptvUseTvFocus(context) && !_editing) {
      if (!_pasteEditing) {
        final arrow = shellTvHandleRowArrows(
          event: event,
          tvMeta: _pasteTvMeta,
          onUpEdge: () {}, // top of dialog — keep focus off header close
          onDownEdge: () => _focusDialogItem(1),
        );
        if (arrow == KeyEventResult.handled) return arrow;

        if (shellTvIsActivateKey(event)) {
          setState(() => _pasteEditing = true);
          return KeyEventResult.handled;
        }
      } else {
        if (shellTvIsNavigationKey(event) &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _pasteEditing = false);
          return KeyEventResult.handled;
        }
      }
    }
    return _pasteKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  int get _dialogTvItemCount {
    if (_editing) return 5;
    if (_showManualForm) return 7;
    return 2;
  }

  int get _dialogOkIndex {
    if (_editing) return 3;
    return _showManualForm ? 5 : 2;
  }

  int get _dialogCancelIndex {
    if (_editing) return 4;
    return _showManualForm ? 6 : 3;
  }

  void _focusDialogItem(int index) {
    if (!mounted || !iptvUseTvFocus(context)) return;
    final clamped = index.clamp(0, _dialogTvItemCount - 1);
    if (_editing) {
      final nodes = [
        _urlFocus,
        _userFocus,
        _passFocus,
        _submitFocus,
        _cancelFocus,
      ];
      nodes[clamped].requestFocus();
      return;
    }
    if (!_showManualForm) {
      switch (clamped) {
        case 0:
          _pasteFocus.requestFocus();
        default:
          _expandFocus.requestFocus();
      }
      return;
    }
    switch (clamped) {
      case 0:
        _pasteFocus.requestFocus();
      case 1:
        _expandFocus.requestFocus();
      case 2:
        _urlFocus.requestFocus();
      case 3:
        _userFocus.requestFocus();
      case 4:
        _passFocus.requestFocus();
      case 5:
        _submitFocus.requestFocus();
      default:
        _cancelFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _unregisterPasteTvNode();
    _pasteFocus.onKeyEvent = _pasteKeyHandler;
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pasteCtrl.dispose();
    _pasteFocus.dispose();
    _urlFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _expandFocus.dispose();
    _submitFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  String _joinedShareCode() => IptvPortalShare.normalizeCode(_pasteCtrl.text);

  int get _activeCodeIndex {
    final sel = _pasteCtrl.selection.baseOffset;
    if (sel >= 0 && sel < _codeLen) return sel;
    return _pasteCtrl.text.length.clamp(0, _codeLen - 1);
  }

  void _onSharePasteChanged(String value) {
    if (_shareCodeError != null) {
      setState(() => _shareCodeError = null);
    }
    _lastImportedCode = null;

    final cleaned = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned != value) {
      _pasteCtrl.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      setState(() {});
      _tryAutoImportShareCode();
      return;
    }
    setState(() {});
    _tryAutoImportShareCode();
  }

  void _toggleManualForm() {
    if (_importingShareCode) return;
    final opening = !_showManualForm;
    setState(() => _showManualForm = !_showManualForm);
    if (opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && iptvUseTvFocus(context)) {
          _focusDialogItem(2);
        } else if (mounted) {
          _urlFocus.requestFocus();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && iptvUseTvFocus(context)) {
          _focusDialogItem(0);
        } else if (mounted) {
          _pasteFocus.requestFocus();
        }
      });
    }
  }

  void _focusShareCodeCell(int index) {
    _pasteFocus.requestFocus();
    final offset = index.clamp(0, _pasteCtrl.text.length);
    _pasteCtrl.selection = TextSelection.collapsed(offset: offset);
    setState(() {});
  }

  Future<void> _tryAutoImportShareCode() async {
    final code = _joinedShareCode();
    if (code.length != _codeLen || _importingShareCode) return;
    if (code == _lastImportedCode) return;
    await _importShareCode(code);
  }

  Future<void> _importShareCode(String code) async {
    if (!IptvPortalShare.isValidCode(code)) return;

    setState(() {
      _importingShareCode = true;
      _shareCodeError = null;
    });

    try {
      final portal = await IptvPortalShare.resolveShare(code);
      if (!mounted) return;
      if (portal == null) {
        setState(() {
          _importingShareCode = false;
          _shareCodeError = 'Share code not found or invalid';
        });
        return;
      }
      _urlCtrl.text = portal.url;
      _userCtrl.text = portal.username;
      _passCtrl.text = portal.password;
      _lastImportedCode = code;
      setState(() => _importingShareCode = false);
      await _submit();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importingShareCode = false;
        _shareCodeError = 'Could not load share code';
      });
    }
  }

  Future<void> _submit() async {
    final ctrl = widget.ctrl;
    if (_editing) {
      await ctrl.updatePortal(
        existing: widget.existing!,
        url: _urlCtrl.text,
        username: _userCtrl.text,
        password: _passCtrl.text,
      );
    } else {
      await ctrl.addManual(
        url: _urlCtrl.text,
        username: _userCtrl.text,
        password: _passCtrl.text,
      );
    }
    if (ctrl.addError == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    widget.ctrl.dismissAddDialog();
    Navigator.of(context).pop();
  }

  Widget _portalDialogCloseButton({required VoidCallback? onTap}) {
    final icon = ForjaPlainIcon(
      icon: Icons.close_rounded,
      tooltip: 'Close',
      color: IptvShellStyle.iconMuted,
      size: 22,
      onTap: onTap,
    );
    if (iptvUseTvFocus(context)) {
      return ExcludeFocus(child: icon);
    }
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final tv = iptvUseTvFocus(context);
    if (tv) {
      iptvSyncRow(
        rowId: 'iptv-portal-dialog',
        sortOrder: 50,
        itemCount: _dialogTvItemCount,
        orientation: ShellTvRowOrientation.vertical,
      );
    } else {
      iptvSyncRow(rowId: 'iptv-portal-dialog', sortOrder: 50, itemCount: 0);
    }
    final urlIndex = _editing ? 0 : (_showManualForm ? 2 : -1);
    final userIndex = _editing ? 1 : (_showManualForm ? 3 : -1);
    final passIndex = _editing ? 2 : (_showManualForm ? 4 : -1);
    final gapAfterTitle = _tv ? 8.0 : (_compact ? 14.0 : 22.0);
    final gapBetweenFields = _tv ? 8.0 : (_compact ? 10.0 : 18.0);
    final gapBeforeManual = _tv ? 8.0 : (_compact ? 12.0 : 20.0);
    final gapBeforeActions = _tv ? 10.0 : (_compact ? 12.0 : 20.0);
    final surfacePadding = _tv
        ? const EdgeInsets.fromLTRB(14, 12, 10, 14)
        : _compact
            ? const EdgeInsets.fromLTRB(16, 16, 12, 16)
            : EdgeInsets.fromLTRB(
                24,
                20,
                16,
                _editing || _showManualForm ? 24 : 32,
              );
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = _tv
        ? (screenH * 0.62).clamp(320.0, 460.0)
        : screenH -
            MediaQuery.viewInsetsOf(context).bottom -
            (_compact ? 32.0 : 64.0);
    final dialogMaxWidth = _tv ? 360.0 : 440.0;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: _tv ? 28 : (_compact ? 20 : 24),
          vertical: _tv ? 36 : (_compact ? 16 : 32),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                DecoratedBox(
                  decoration: IptvShellStyle.dialogSurface(),
                  child: Padding(
                    padding: surfacePadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _editing ? 'Edit Portal' : 'Add Portal',
                                style: IptvShellStyle.overlayTitle.copyWith(
                                  fontSize: _tv ? 17 : 19,
                                ),
                              ),
                            ),
                            _portalDialogCloseButton(
                              onTap: ctrl.isAdding ? null : _cancel,
                            ),
                          ],
                        ),
                        SizedBox(height: gapAfterTitle),
                        Flexible(
                          fit: FlexFit.loose,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_editing) _shareCodeSection(),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  clipBehavior: Clip.hardEdge,
                                  child: _editing || _showManualForm
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (!_editing)
                                              SizedBox(height: gapBeforeManual),
                                            _portalField(
                                              _urlCtrl,
                                              'URL',
                                              hint:
                                                  'http://portal.example.com:8080',
                                              focusNode: _urlFocus,
                                              dialogIndex: urlIndex,
                                            ),
                                            SizedBox(height: gapBetweenFields),
                                            _portalField(
                                              _userCtrl,
                                              'Username',
                                              hint: 'username',
                                              focusNode: _userFocus,
                                              dialogIndex: userIndex,
                                            ),
                                            SizedBox(height: gapBetweenFields),
                                            _portalField(
                                              _passCtrl,
                                              'Password',
                                              hint: 'password',
                                              obscure: _obscurePassword,
                                              focusNode: _passFocus,
                                              dialogIndex: passIndex,
                                              suffix: ForjaPlainIcon(
                                                icon: _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined,
                                                tooltip: _obscurePassword
                                                    ? 'Show password'
                                                    : 'Hide password',
                                                color: IptvShellStyle.iconMuted,
                                                size: 20,
                                                onTap: () => setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const SizedBox(width: double.infinity),
                                ),
                                if (ctrl.addError != null) ...[
                                  SizedBox(height: _tv ? 6 : (_compact ? 8 : 12)),
                                  Text(
                                    ctrl.addError!,
                                    style: GoogleFonts.poppins(
                                      color: IptvShellStyle.liveBadge,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!ctrl.isAdding && (_editing || _showManualForm)) ...[
                          SizedBox(height: gapBeforeActions),
                          Row(
                            children: [
                              Expanded(
                                child: IptvPrimaryButton(
                                  icon: Icons.check_rounded,
                                  label: _editing ? 'Save' : 'Add',
                                  dense: _dense,
                                  focusNode: _submitFocus,
                                  tvRowId: 'iptv-portal-dialog',
                                  tvItemIndex: _dialogOkIndex,
                                  onPressed: _submit,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: IptvPrimaryButton(
                                  icon: Icons.close_rounded,
                                  label: 'Cancel',
                                  subtle: true,
                                  dense: _dense,
                                  focusNode: _cancelFocus,
                                  tvRowId: 'iptv-portal-dialog',
                                  tvItemIndex: _dialogCancelIndex,
                                  onPressed: _cancel,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (ctrl.isAdding) ...[
                          SizedBox(height: _tv ? 10 : (_compact ? 12 : 16)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: IptvShellStyle.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _editing ? 'Saving…' : 'Adding portal…',
                                style: GoogleFonts.poppins(
                                  color: IptvShellStyle.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!_editing)
                  Positioned(bottom: -13, child: _manualFormToggle()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualFormToggle() {
    const size = 26.0;
    final tvFocused =
        iptvUseTvFocus(context) && _expandFocused;
    final active = iptvUseTvFocus(context) &&
        iptvFocusActive(context, hovered: false, focused: _expandFocused);
    final child = Tooltip(
      message: _showManualForm ? 'Hide manual entry' : 'Enter URL manually',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: active
            ? iptvFocusButtonDecoration(
                active: true,
                tvFocused: tvFocused,
                borderRadius: 7,
                idleBg: IptvShellStyle.surface,
                idleBorder: IptvShellStyle.border,
                subtle: true,
              )
            : BoxDecoration(
                color: IptvShellStyle.surface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: IptvShellStyle.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
        child: Icon(
          _showManualForm
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: iptvFocusFg(
            IptvShellStyle.textSecondary,
            active: active,
            tvFocused: tvFocused,
          ),
          size: 16,
        ),
      ),
    );
    if (iptvUseTvFocus(context)) {
      return iptvTap(
        context: context,
        onTap: _importingShareCode ? null : _toggleManualForm,
        borderRadius: 7,
        focusNode: _expandFocus,
        tvRowId: 'iptv-portal-dialog',
        tvItemIndex: 1,
        onUpEdge: () => _focusDialogItem(0),
        onDownEdge: () =>
            _focusDialogItem(_showManualForm ? 2 : 1),
        onFocusChange: (focused) => setState(() => _expandFocused = focused),
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _importingShareCode ? null : _toggleManualForm,
        borderRadius: BorderRadius.circular(7),
        child: child,
      ),
    );
  }

  Widget _shareCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SHARE CODE',
          style: GoogleFonts.poppins(
            color: IptvShellStyle.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: _tv ? 6 : (_compact ? 8 : 14)),
        SizedBox(
          height: _codeBoxHeight,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _shareCodeCell(i),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '-',
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: _tv ? 14 : (_compact ? 16 : 22),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  for (var i = 4; i < 8; i++) ...[
                    if (i > 4) const SizedBox(width: 6),
                    _shareCodeCell(i),
                  ],
                ],
              ),
              Positioned.fill(
                child: TextField(
                  controller: _pasteCtrl,
                  focusNode: _pasteFocus,
                  enabled: !_importingShareCode,
                  readOnly: iptvUseTvFocus(context) && !_pasteEditing,
                  enableInteractiveSelection:
                      !iptvUseTvFocus(context) || _pasteEditing,
                  maxLength: _codeLen,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  showCursor: false,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  onChanged: _onSharePasteChanged,
                ),
              ),
            ],
          ),
        ),
        if (_importingShareCode) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IptvShellStyle.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Adding portal…',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
        if (_shareCodeError != null) ...[
          const SizedBox(height: 10),
          Text(
            _shareCodeError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: IptvShellStyle.liveBadge,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _shareCodeCell(int index) {
    final text = index < _pasteCtrl.text.length ? _pasteCtrl.text[index] : '';
    final pasteFocused = _pasteFocus.hasFocus;
    final active = pasteFocused && index == _activeCodeIndex;
    final borderColor = iptvDialogFieldBorderColor(focused: pasteFocused);
    return GestureDetector(
      onTap: () => _focusShareCodeCell(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _codeBoxWidth,
        height: _codeBoxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: pasteFocused ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            color: IptvShellStyle.textPrimary,
            fontSize: _codeFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _portalField(
    TextEditingController c,
    String label, {
    String? hint,
    bool obscure = false,
    Widget? suffix,
    FocusNode? focusNode,
    int dialogIndex = -1,
  }) {
    final tv = iptvUseTvFocus(context);
    final compact = _dense;
    final hintStyle = GoogleFonts.poppins(
      color: Colors.white.withValues(alpha: 0.25),
      fontSize: _tv ? 12 : (compact ? 13 : 14),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            color: IptvShellStyle.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: _tv ? 3 : (compact ? 4 : 6)),
        if (tv && focusNode != null && dialogIndex >= 0)
          _IptvPortalDialogField(
            controller: c,
            focusNode: focusNode,
            obscureText: obscure,
            hintText: hint,
            hintStyle: hintStyle,
            suffixIcon: suffix,
            style: GoogleFonts.poppins(
              color: IptvShellStyle.textPrimary,
              fontSize: _tv ? 13 : 14,
            ),
            onArrowUp: () => _focusDialogItem(dialogIndex - 1),
            onArrowDown: () => _focusDialogItem(dialogIndex + 1),
          )
        else
          TextField(
            controller: c,
            focusNode: focusNode,
            obscureText: obscure,
            style: GoogleFonts.poppins(
              color: IptvShellStyle.textPrimary,
              fontSize: _tv ? 12 : (compact ? 13 : 14),
            ),
            decoration: iptvDialogFieldDecoration(
              focused: focusNode?.hasFocus ?? false,
              hintText: hint,
              hintStyle: hintStyle,
              suffixIcon: suffix,
            ).copyWith(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: _tv ? 7 : (compact ? 8 : 10),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog form field — TV browse mode: focus highlights; Enter opens keyboard.
class _IptvPortalDialogField extends StatefulWidget {
  const _IptvPortalDialogField({
    required this.controller,
    required this.focusNode,
    required this.onArrowUp,
    required this.onArrowDown,
    this.obscureText = false,
    this.style,
    this.hintText,
    this.hintStyle,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onArrowUp;
  final VoidCallback onArrowDown;
  final bool obscureText;
  final TextStyle? style;
  final String? hintText;
  final TextStyle? hintStyle;
  final Widget? suffixIcon;

  @override
  State<_IptvPortalDialogField> createState() => _IptvPortalDialogFieldState();
}

class _IptvPortalDialogFieldState extends State<_IptvPortalDialogField> {
  FocusOnKeyEventCallback? _previousHandler;
  bool _editing = false;

  bool get _tvBrowse => iptvUseTvFocus(context) && !_editing;

  @override
  void initState() {
    super.initState();
    _attachKeyHandler();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _IptvPortalDialogField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      oldWidget.focusNode.onKeyEvent = _previousHandler;
      _attachKeyHandler();
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && _editing && mounted) {
      setState(() => _editing = false);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _attachKeyHandler() {
    _previousHandler = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _handleKey;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.focusNode.onKeyEvent = _previousHandler;
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_tvBrowse && shellTvIsActivateKey(event)) {
      setState(() => _editing = true);
      return KeyEventResult.handled;
    }
    if (_tvBrowse && event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onArrowDown();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.onArrowUp();
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _editing) {
      setState(() => _editing = false);
      return KeyEventResult.handled;
    }
    return _previousHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tv = iptvUseTvFocus(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.obscureText,
      readOnly: tv && !_editing,
      enableInteractiveSelection: !tv || _editing,
      style: widget.style,
      decoration: iptvDialogFieldDecoration(
        focused: widget.focusNode.hasFocus,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}

class _PortalHoverTile extends StatefulWidget {
  const _PortalHoverTile({
    required this.portal,
    required this.ctrl,
    required this.isActive,
    required this.listIndex,
    required this.onEdit,
    this.onUpEdge,
  });

  final VerifiedPortal portal;
  final IptvController ctrl;
  final bool isActive;
  final int listIndex;
  final VoidCallback onEdit;
  final VoidCallback? onUpEdge;

  @override
  State<_PortalHoverTile> createState() => _PortalHoverTileState();
}

class _PortalHoverTileState extends State<_PortalHoverTile> {
  static const _actionW = 108.0;
  static const _statusSlot = 18.0;
  static const _rowH = 66.0;

  bool _lineHover = false;
  bool _focused = false;
  bool _sharing = false;
  bool _showShareCode = false;
  String? _shareCode;
  late final FocusNode _favoriteFocus;
  late final FocusNode _copyFocus;
  late final FocusNode _editFocus;
  late final FocusNode _deleteFocus;

  bool get _reveal => _focused || _lineHover;

  double get _rowHeight => _rowH;

  @override
  void initState() {
    super.initState();
    _favoriteFocus = FocusNode(debugLabel: 'iptv-portal-favorite');
    _copyFocus = FocusNode(debugLabel: 'iptv-portal-copy');
    _editFocus = FocusNode(debugLabel: 'iptv-portal-edit');
    _deleteFocus = FocusNode(debugLabel: 'iptv-portal-delete');
  }

  @override
  void dispose() {
    _favoriteFocus.dispose();
    _copyFocus.dispose();
    _editFocus.dispose();
    _deleteFocus.dispose();
    super.dispose();
  }

  void _focusCatalogFromPanel() {
    iptvFocusBrowserCategories(widget.ctrl);
  }

  String get _actionsRowId => 'portal-${widget.listIndex}-actions';

  void _clearHover() {
    setState(() => _lineHover = false);
  }

  Future<void> _copy() async {
    if (_sharing) return;

    if (_shareCode != null) {
      setState(() => _showShareCode = true);
      await Clipboard.setData(ClipboardData(text: _shareCode!));
      ForjaToast.success(
        'Share code copied',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _sharing = true);
    try {
      final code = await IptvPortalShare.createShare(widget.portal.portal);
      if (!mounted) return;
      _shareCode = code;
      setState(() {
        _sharing = false;
        _showShareCode = true;
      });
      await Clipboard.setData(ClipboardData(text: code));
      ForjaToast.success(
        'Share code copied',
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ForjaToast.error('Could not create share code');
    }
  }

  void _onRowTap() {
    if (_showShareCode) {
      setState(() => _showShareCode = false);
      return;
    }
    widget.ctrl.selectPortal(widget.portal);
  }

  PlayerSourceStatus _activePortalStatus({
    required bool checking,
    required bool? health,
  }) {
    if (checking) return PlayerSourceStatus.checking;
    if (health == false) return PlayerSourceStatus.failed;
    return PlayerSourceStatus.active;
  }

  Widget _activePortalStatusGlyph(PlayerSourceStatus status) {
    final color = playerSourceStatusColor(status);
    final Widget glyph = switch (status) {
      PlayerSourceStatus.active => Icon(
        Icons.play_circle_filled_rounded,
        color: color,
        size: _statusSlot,
      ),
      PlayerSourceStatus.failed => Icon(
        Icons.cancel_rounded,
        color: color,
        size: _statusSlot,
      ),
      PlayerSourceStatus.checking => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
      PlayerSourceStatus.ready => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    };
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(child: glyph),
    );
  }

  Widget _idlePortalHealthDot({required bool checking, required bool? health}) {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: checking
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white54,
                ),
              )
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: health == true
                      ? playerSourceStatusColor(PlayerSourceStatus.active)
                      : health == false
                      ? playerSourceStatusColor(PlayerSourceStatus.failed)
                      : playerSourceStatusColor(PlayerSourceStatus.ready),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final v = widget.portal;
    final isActive = widget.isActive;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final isFav = ctrl.isFavoritePortal(v.key);
        final isNew = ctrl.isNewPortal(v.key);
        final showNewChrome = isNew && !_reveal && !_showShareCode;
        final health = ctrl.portalHealthFor(v.key);
        final checking = ctrl.isPortalHealthChecking(v.key);
        final title = v.name.trim().isEmpty
            ? (v.portal.username.trim().isEmpty ? 'Portal' : v.portal.username)
            : v.name.trim();

        if (_reveal) {
          iptvSyncRow(
            rowId: _actionsRowId,
            sortOrder: 200 + widget.listIndex,
            itemCount: 4,
          );
        }

        return MouseRegion(
          onEnter: (_) {
            setState(() => _lineHover = true);
            if (isNew) ctrl.markPortalSeen(v.key);
            ctrl.schedulePortalHealthCheck(v);
          },
          onExit: (_) {
            _clearHover();
            ctrl.cancelPortalHealthCheck(v.key);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isActive
                  ? playerSourceStatusColor(
                      PlayerSourceStatus.active,
                    ).withValues(alpha: 0.07)
                  : showNewChrome
                  ? IptvShellStyle.accent.withValues(alpha: 0.1)
                  : (_lineHover || _focused || _showShareCode)
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              border: showNewChrome
                  ? Border(
                      left: BorderSide(color: IptvShellStyle.accent, width: 3),
                    )
                  : null,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: _rowHeight,
              alignment: Alignment.topCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: iptvTap(
                      context: context,
                      onTap: _onRowTap,
                      borderRadius: 0,
                      listIndex: widget.listIndex,
                      tvRowId: 'portals',
                      tvItemIndex: widget.listIndex,
                      onUpEdge: widget.onUpEdge,
                      onLeftEdge: _reveal
                          ? () => _favoriteFocus.requestFocus()
                          : _focusCatalogFromPanel,
                      onRightEdge: _reveal
                          ? () => _copyFocus.requestFocus()
                          : null,
                      onFocusChange: (focused) {
                        setState(() => _focused = focused);
                        if (focused) {
                          if (ctrl.isNewPortal(v.key)) {
                            ctrl.markPortalSeen(v.key);
                          }
                          ctrl.schedulePortalHealthCheck(v);
                        } else {
                          ctrl.cancelPortalHealthCheck(v.key);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: isActive
                                  ? _activePortalStatusGlyph(
                                      _activePortalStatus(
                                        checking: checking,
                                        health: health,
                                      ),
                                    )
                                  : _idlePortalHealthDot(
                                      checking: checking,
                                      health: health,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _showShareCode || _sharing
                                  ? _shareCodeLine()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _expiryLine(v.expiry),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (showNewChrome) ...[
                                              _newPortalBadge(),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: isActive
                                                      ? Colors.white
                                                      : showNewChrome
                                                      ? IptvShellStyle.accent
                                                      : Colors.white.withValues(
                                                          alpha: 0.88,
                                                        ),
                                                  fontSize: 13,
                                                  fontWeight:
                                                      isActive || showNewChrome
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          v.portal.url,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            color: showNewChrome
                                                ? Colors.white54
                                                : Colors.white38,
                                            fontSize: 11,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: iptvTap(
                                context: context,
                                onTap: () => ctrl.toggleFavoritePortal(v.key),
                                borderRadius: 16,
                                focusNode: _favoriteFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 0,
                                onLeftEdge: _focusCatalogFromPanel,
                                onRightEdge: _reveal
                                    ? () => _copyFocus.requestFocus()
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isFav
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: isFav
                                        ? const Color(0xFFFBBF24)
                                        : Colors.white30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: _reveal ? _actionW : 0,
                    height: _rowHeight,
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: _actionW,
                        maxWidth: _actionW,
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: _actionW,
                          height: _rowHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _IptvRailAction(
                                tooltip: 'Copy share code',
                                icon: _sharing
                                    ? Icons.hourglass_top_rounded
                                    : Icons.copy_rounded,
                                color: Colors.white60,
                                onTap: _sharing ? null : _copy,
                                focusNode: _copyFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 1,
                                onLeftEdge: () => _favoriteFocus.requestFocus(),
                                onRightEdge: () => _editFocus.requestFocus(),
                              ),
                              _IptvRailAction(
                                tooltip: 'Edit',
                                icon: Icons.edit_rounded,
                                color: Colors.white60,
                                onTap: widget.onEdit,
                                focusNode: _editFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 2,
                                onLeftEdge: () => _copyFocus.requestFocus(),
                                onRightEdge: () => _deleteFocus.requestFocus(),
                              ),
                              _IptvRailAction(
                                tooltip: 'Delete',
                                icon: Icons.delete_rounded,
                                color: const Color(0xFFEF4444),
                                onTap: () => ctrl.deletePortal(v.key),
                                focusNode: _deleteFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 3,
                                onLeftEdge: () => _editFocus.requestFocus(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _shareCodeLine() {
    if (_sharing) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: IptvShellStyle.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Creating share code…',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SHARE CODE · TAP ROW TO HIDE',
          style: GoogleFonts.poppins(
            color: IptvShellStyle.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _shareCode ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            color: IptvShellStyle.accent,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _expiryLine(String expiry) {
    final tone = _portalExpiryTone(expiry);
    return Row(
      children: [
        Icon(Icons.event_rounded, size: 12, color: tone.color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            tone.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: tone.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _newPortalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: IptvShellStyle.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IptvShellStyle.accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        'NEW',
        style: GoogleFonts.poppins(
          color: IptvShellStyle.accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }

}

class _IptvRailAction extends StatefulWidget {
  const _IptvRailAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
    this.focusNode,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_IptvRailAction> createState() => _IptvRailActionState();
}

class _IptvRailActionState extends State<_IptvRailAction> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final tvFocused = iptvTvFocused(context, focused: _focused);
    final fg = iptvFocusFg(
      widget.color,
      active: _active,
      tvFocused: tvFocused,
    );
    final child = SizedBox(
      width: 32,
      height: 32,
      child: Icon(widget.icon, size: 16, color: fg),
    );
    if (iptvUseTvFocus(context)) {
      return Tooltip(
        message: widget.tooltip,
        child: iptvTap(
          context: context,
          onTap: widget.onTap,
          borderRadius: 6,
          focusNode: widget.focusNode,
          tvRowId: widget.tvRowId,
          tvItemIndex: widget.tvItemIndex,
          onLeftEdge: widget.onLeftEdge,
          onRightEdge: widget.onRightEdge,
          onFocusChange: (focused) => setState(() => _focused = focused),
          onHoverChange: (hovered) => setState(() => _hovered = hovered),
          child: child,
        ),
      );
    }
    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: child,
        ),
      ),
    );
  }
}
