import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
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

  void _focusDownFromTopBar() {
    if (!iptvFocusRowItem('browser-categories') &&
        !iptvFocusRowItem('browser-category-chips')) {
      iptvFocusRowItem('browser-streams');
    }
  }

  void _openSearch() {
    if (ctrl.browserSearchOpen) return;
    ctrl.openBrowserSearch();
  }

  void _closeSearch() {
    ctrl.closeBrowserSearch();
  }

  @override
  Widget build(BuildContext context) {
    iptvSyncRow(
      rowId: 'iptv-sections',
      sortOrder: 0,
      itemCount: _kSectionShelf.length,
    );
    iptvSyncRow(
      rowId: 'iptv-top-tools',
      sortOrder: 1,
      itemCount: 2,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShellTokens.bodyHorizontalPadding,
        10,
        12,
        8,
      ),
      child: Row(
        children: [
          _buildShelf(context),
          const Spacer(),
          _buildExpandingSearch(context),
          const SizedBox(width: 8),
          _buildPortalButton(context),
        ],
      ),
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
              onDownEdge: _focusDownFromTopBar,
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

  Widget _buildSearchIcon(BuildContext context) {
    return iptvTap(
      context: context,
      onTap: _openSearch,
      borderRadius: _kSearchCollapsed / 2,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 0,
      onDownEdge: _focusDownFromTopBar,
      onLeftEdge: () =>
          iptvFocusRowItem('iptv-sections', _kSectionShelf.length - 1),
      onRightEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
      child: Container(
        width: _kSearchCollapsed,
        height: _kSearchCollapsed,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
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

  Widget _buildPortalButton(BuildContext context) {
    final selected = ctrl.portalPanelOpen;
    final hasPortal = ctrl.activePortal != null;
    return iptvTap(
      context: context,
      onTap: widget.onTogglePanel,
      borderRadius: _kShelfTabRadius,
      tvZone: ShellTvZone.topBar,
      tvRowId: 'iptv-top-tools',
      tvItemIndex: 1,
      onDownEdge: _focusDownFromTopBar,
      onLeftEdge: () => iptvFocusRowItem('iptv-top-tools', 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: _kShelfTabHeight,
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(_kShelfTabRadius),
          border: Border.all(
            color: !hasPortal
                ? IptvShellStyle.accent.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: selected ? 0.28 : 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPortal ? Icons.dns_rounded : Icons.add_link_rounded,
              size: 16,
              color: hasPortal ? Colors.white : IptvShellStyle.accent,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                _portalLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              selected ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
              color: Colors.white60,
            ),
          ],
        ),
      ),
    );
  }
}

/// Solid rectangle shelf tab — color only when selected / hovered / focused.
class _IptvSectionShelfTab extends StatefulWidget {
  const _IptvSectionShelfTab({
    required this.spec,
    required this.selected,
    required this.listIndex,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    this.onDownEdge,
    this.onRightEdge,
  });

  final _IptvSectionShelfSpec spec;
  final bool selected;
  final int listIndex;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_IptvSectionShelfTab> createState() => _IptvSectionShelfTabState();
}

class _IptvSectionShelfTabState extends State<_IptvSectionShelfTab> {
  bool _hover = false;
  bool _focused = false;

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
    final showColor = widget.selected || _hover || _focused;
    // Prefer the vivid accent (Series stores green as second stop).
    final accent = widget.spec.section == IptvSection.series
        ? widget.spec.colors.last
        : widget.spec.colors.first;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: iptvTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: _kShelfTabRadius,
        scaleOnFocus: 1.0,
        tvZone: ShellTvZone.topBar,
        tvRowId: 'iptv-sections',
        listIndex: widget.listIndex,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        onRightEdge: widget.onRightEdge,
        onLeftEdge: widget.listIndex == 0
            ? null
            : () => iptvFocusRowItem('iptv-sections', widget.listIndex - 1),
        onFocusChange: (f) => setState(() => _focused = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: _kShelfTabHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: showColor
                ? (widget.selected
                    ? accent
                    : accent.withValues(alpha: 0.55))
                : Colors.transparent,
            borderRadius: _radius,
          ),
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
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
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
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_searchOpen) {
            _closeSearch();
            return KeyEventResult.handled;
          }
          widget.onClose();
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
              if (ctrl.editMode && ctrl.verified.isNotEmpty) _buildEditBar(),
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
                          color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search portals…',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.white54, size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          ),
          IptvIconAction(
            tooltip: ctrl.isScraping ? 'Stop scrape' : 'Scrape portals',
            onPressed: ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
            icon: ctrl.isScraping
                ? Icons.stop_circle_rounded
                : Icons.travel_explore_rounded,
            color: ctrl.isScraping ? IptvShellStyle.accent : null,
          ),
          IptvIconAction(
            tooltip: 'Add portal',
            onPressed: () => _showAddDialog(context),
            icon: Icons.add_rounded,
          ),
          if (ctrl.verified.isNotEmpty)
            IptvIconAction(
              tooltip: ctrl.editMode ? 'Done' : 'Edit',
              onPressed: ctrl.toggleEditMode,
              icon: ctrl.editMode ? Icons.check_rounded : Icons.edit_rounded,
              color: ctrl.editMode ? IptvShellStyle.accent : Colors.white70,
            ),
          iptvCloseButton(context, onTap: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildEditBar() {
    final ctrl = widget.ctrl;
    final allSelected = ctrl.selected.length == ctrl.verified.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: IptvShellStyle.chipSelectedBg.withValues(alpha: 0.35),
      child: Row(
        children: [
          IptvTextAction(
            icon: allSelected ? Icons.deselect : Icons.select_all,
            label: allSelected ? 'Clear' : 'All',
            onPressed: ctrl.toggleSelectAll,
          ),
          const Spacer(),
          Text(
            '${ctrl.selected.length} selected',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          IptvIconAction(
            tooltip: 'Delete selected',
            onPressed: ctrl.selected.isEmpty ? null : ctrl.deleteSelected,
            icon: Icons.delete_rounded,
            color: ctrl.selected.isEmpty
                ? Colors.white24
                : const Color(0xFFEF4444),
          ),
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
            Icon(Icons.satellite_alt_rounded,
                size: 48, color: IptvShellStyle.accent),
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final v = list[i];
        final isActive = v.key == activeKey;
        final isSelected = ctrl.selected.contains(v.key);
        final isFav = ctrl.isFavoritePortal(v.key);
        final health = ctrl.portalHealthFor(v.key);
        final checking = ctrl.isPortalHealthChecking(v.key);
        return MouseRegion(
          onEnter: (_) => ctrl.schedulePortalHealthCheck(v),
          onExit: (_) => ctrl.cancelPortalHealthCheck(v.key),
          child: iptvTap(
            context: context,
            onTap: () {
              if (ctrl.editMode) {
                ctrl.toggleSelect(v.key);
              } else {
                ctrl.selectPortal(v);
              }
            },
            borderRadius: 10,
            listIndex: i,
            tvRowId: 'portals',
            tvItemIndex: i,
            onFocusChange: (focused) {
              if (focused) {
                ctrl.schedulePortalHealthCheck(v);
              } else {
                ctrl.cancelPortalHealthCheck(v.key);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: health == false
                    ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                    : isActive
                        ? IptvShellStyle.accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _portalBorderColor(
                    health: health,
                    isActive: isActive,
                    isSelected: isSelected,
                  ),
                  width: isActive || isSelected || health != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (ctrl.editMode)
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? IptvShellStyle.accent
                          : Colors.white30,
                      size: 20,
                    )
                  else
                    Icon(Icons.tv_rounded,
                        color: Colors.white.withValues(alpha: 0.5), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name.trim().isEmpty ? v.portal.url : v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          v.portal.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (checking)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white54,
                      ),
                    )
                  else if (health != null)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: health
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  if (!ctrl.editMode)
                    iptvTap(
                      context: context,
                      onTap: () => ctrl.toggleFavoritePortal(v.key),
                      borderRadius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFav
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 18,
                          color: isFav
                              ? const Color(0xFFFBBF24)
                              : Colors.white38,
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

  Color _portalBorderColor({
    required bool? health,
    required bool isActive,
    required bool isSelected,
  }) {
    if (health == true) {
      return const Color(0xFF22C55E).withValues(alpha: 0.55);
    }
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: 0.65);
    }
    if (isActive || isSelected) return IptvShellStyle.accent;
    return Colors.white.withValues(alpha: 0.06);
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final ctrl = widget.ctrl;
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => ShellScope.rehost(
        context,
        AnimatedBuilder(
          animation: ctrl,
          builder: (_, _) => AlertDialog(
            backgroundColor: IptvShellStyle.surface,
            title: Text(
              'Add Portal',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 26),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _portalInput(urlCtrl, 'http://portal.example.com:8080', 'URL'),
                  const SizedBox(height: 8),
                  _portalInput(userCtrl, 'username', 'Username'),
                  const SizedBox(height: 8),
                  _portalInput(passCtrl, 'password', 'Password', obscure: true),
                  if (ctrl.addError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      ctrl.addError!,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              IptvTextAction(
                icon: Icons.close_rounded,
                label: 'Cancel',
                color: Colors.white70,
                onPressed: ctrl.isAdding
                    ? null
                    : () {
                        ctrl.dismissAddDialog();
                        Navigator.of(ctx).pop();
                      },
              ),
              IptvPrimaryButton(
                icon: Icons.add_rounded,
                label: ctrl.isAdding ? 'Adding…' : 'Add',
                busy: ctrl.isAdding,
                onPressed: ctrl.isAdding
                    ? null
                    : () async {
                        await ctrl.addManual(
                          url: urlCtrl.text,
                          username: userCtrl.text,
                          password: passCtrl.text,
                        );
                        if (ctrl.addError == null && ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portalInput(
    TextEditingController c,
    String hint,
    String label, {
    bool obscure = false,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}
