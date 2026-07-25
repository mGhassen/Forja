part of 'iptv_catalog_workspace.dart';

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
  bool _sortToolFocused = false;
  bool _sortToolHovered = false;
  bool _portalToolFocused = false;
  bool _portalToolHovered = false;
  final GlobalKey _sortAnchorKey = GlobalKey();

  IptvController get ctrl => widget.ctrl;

  bool get _showLiveSort => ctrl.activeSection == IptvSection.live;

  /// Cards / EPG toggle - Live + wide desktop only (not TV / compact bar).
  bool _showLiveLayoutToggle(BuildContext context, {required bool compact}) {
    if (!_showLiveSort || compact) return false;
    return !ShellScope.metricsOf(context).usesTvDensity;
  }

  /// Live: Search · Sort · Portals. Else: Search · Portals.
  /// (Cards/EPG toggle sits next to the shelf - not in this focus row.)
  int get _searchToolIndex => 0;

  int get _sortToolIndex => 1;

  int get _topToolsCount => _showLiveSort ? 3 : 2;

  int get _portalToolIndex => _showLiveSort ? 2 : 1;

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
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
  }

  bool _handleFindShortcut() {
    if (ctrl.activePortal == null) return false;
    _focusSearchFromShortcut();
    return true;
  }

  void _focusSearchFromShortcut() {
    if (!mounted) return;
    final compact = MediaQuery.sizeOf(context).width < 760;
    if (compact) {
      unawaited(_openSearch(context, compact: true));
      return;
    }
    if (!ctrl.browserSearchOpen) {
      ctrl.openBrowserSearch();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    ShellBus.unregisterFindShortcutHandler(_handleFindShortcut);
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
    return p.displayLabel;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final showLayout = _showLiveLayoutToggle(context, compact: compact);
        iptvSyncRow(
          rowId: 'iptv-top-tools',
          sortOrder: 1,
          itemCount: _topToolsCount,
        );
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildShelf(context),
                        if (showLayout) ...[
                          const SizedBox(width: 8),
                          _buildLiveLayoutToggle(context),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              compact
                  ? _buildSearchIcon(context, compact: true)
                  : _buildExpandingSearch(context),
              if (_showLiveSort) ...[
                const SizedBox(width: 8),
                _buildSortButton(context),
              ],
              const SizedBox(width: 8),
              _buildPortalButton(context, compact: compact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveLayoutToggle(BuildContext context) {
    final guide = ctrl.liveBrowseLayout == IptvLiveBrowseLayout.guide;
    return Container(
      height: _kShelfTabHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_kShelfTabHeight / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveLayoutToggleSlot(
            icon: Icons.grid_view_rounded,
            selected: !guide,
            isFirst: true,
            isLast: false,
            onTap: () {
              unawaited(ctrl.setLiveBrowseLayout(IptvLiveBrowseLayout.cards));
            },
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.14),
          ),
          _LiveLayoutToggleSlot(
            icon: Icons.table_chart_outlined,
            selected: guide,
            isFirst: false,
            isLast: true,
            onTap: () {
              unawaited(ctrl.setLiveBrowseLayout(IptvLiveBrowseLayout.guide));
            },
          ),
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
      tvItemIndex: _searchToolIndex,
      onDownEdge: _focusDownFromTopTools,
      onLeftEdge: () =>
          iptvFocusRowItem('iptv-sections', _kSectionShelf.length - 1),
      onRightEdge: () => iptvFocusRowItem(
        'iptv-top-tools',
        _showLiveSort ? _sortToolIndex : _portalToolIndex,
      ),
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

  Widget _buildSortButton(BuildContext context) {
    final active = iptvFocusActive(
      context,
      hovered: _sortToolHovered,
      focused: _sortToolFocused,
    );
    final tvFocused = iptvTvFocused(context, focused: _sortToolFocused);
    final customSort = ctrl.liveCategorySort != IptvCatalogSort.playlist ||
        ctrl.liveContentSort != IptvCatalogSort.playlist;
    return KeyedSubtree(
      key: _sortAnchorKey,
      child: iptvTap(
        context: context,
        onTap: () => _openSortMenu(context),
        borderRadius: _kSearchCollapsed / 2,
        tvZone: ShellTvZone.topBar,
        tvRowId: 'iptv-top-tools',
        tvItemIndex: _sortToolIndex,
        onDownEdge: _focusDownFromTopTools,
        onLeftEdge: () => iptvFocusRowItem('iptv-top-tools', _searchToolIndex),
        onRightEdge: () =>
            iptvFocusRowItem('iptv-top-tools', _portalToolIndex),
        onFocusChange: (focused) => setState(() => _sortToolFocused = focused),
        onHoverChange: (hovered) => setState(() => _sortToolHovered = hovered),
        child: Tooltip(
          message: 'Sort',
          child: Container(
            width: _kSearchCollapsed,
            height: _kSearchCollapsed,
            decoration: BoxDecoration(
              color: iptvFocusSurfaceColor(
                active: active || customSort,
                tvFocused: tvFocused,
                idleAlpha: customSort ? 0.12 : 0.08,
              ),
              borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
              border: Border.all(
                color: iptvFocusOutlineColor(
                  active: active || customSort,
                  tvFocused: tvFocused,
                  idleAlpha: customSort ? 0.22 : 0.12,
                  hoverAlpha: 0.22,
                ),
                width: tvFocused ? 1.5 : 1,
              ),
            ),
            child: Icon(
              Icons.sort_rounded,
              color: iptvFocusFg(
                customSort ? Colors.white : Colors.white60,
                active: active,
                tvFocused: tvFocused,
              ),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _openSortMenu(BuildContext context) {
    PlayerPopupPanel.show(
      context: context,
      title: 'Sort',
      showHeader: false,
      anchorContext: _sortAnchorKey.currentContext,
      alignment: Alignment.topRight,
      margin: const EdgeInsets.only(right: 12, top: 56),
      width: 280,
      maxHeight: 420,
      shellBg: ForjaShellColors.surfaceElevated,
      child: _IptvLiveSortMenu(
        categorySort: ctrl.liveCategorySort,
        contentSort: ctrl.liveContentSort,
        onCategorySort: (sort) {
          unawaited(ctrl.setLiveCategorySort(sort));
        },
        onContentSort: (sort) {
          unawaited(ctrl.setLiveContentSort(sort));
        },
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
              browseHintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 13,
              ),
              caretHeight: 16,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
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
    final portal = ctrl.activePortal;
    final hasPortal = portal != null;
    final active = iptvFocusActive(
      context,
      hovered: _portalToolHovered,
      focused: _portalToolFocused,
    );
    final tvFocused = iptvTvFocused(context, focused: _portalToolFocused);
    final showHighlight = selected || active;
    final revealSeats =
        hasPortal && (_portalToolHovered || _portalToolFocused);
    final health =
        portal == null ? null : ctrl.portalHealthFor(portal.key);
    final checking =
        portal != null && ctrl.isPortalHealthChecking(portal.key);

    // Idle min keeps short names from pinching; hover grows for seats.
    final minW = compact ? _kSearchCollapsed : 156.0;
    final maxW = compact
        ? (revealSeats ? 96.0 : _kSearchCollapsed)
        : (revealSeats ? 300.0 : 260.0);
    final chipRadius = BorderRadius.circular(_kShelfTabRadius);
    final borderColor = tvFocused
        ? ForjaShellColors.brandGreen
        : !hasPortal
            ? IptvShellStyle.accent.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: showHighlight ? 0.28 : 0.10);
    final borderW = tvFocused ? 1.5 : 1.0;
    final side = BorderSide(color: borderColor, width: borderW);

    return Align(
      alignment: Alignment.centerRight,
      child: iptvTap(
        context: context,
        onTap: widget.onTogglePanel,
        borderRadius: _kShelfTabRadius,
        tvZone: ShellTvZone.topBar,
        tvRowId: 'iptv-top-tools',
        tvItemIndex: _portalToolIndex,
        onDownEdge: _focusDownFromPortalTool,
        onLeftEdge: () =>
            iptvFocusRowItem('iptv-top-tools', _portalToolIndex - 1),
        onRightEdge:
            selected ? () => iptvFocusRowItem('portals', 0) : null,
        onFocusChange: (focused) {
          setState(() => _portalToolFocused = focused);
          final p = ctrl.activePortal;
          if (p == null) return;
          if (focused) {
            ctrl.schedulePortalHealthCheck(p);
          } else if (!_portalToolHovered) {
            ctrl.cancelPortalHealthCheck(p.key);
          }
        },
        onHoverChange: (hovered) {
          setState(() => _portalToolHovered = hovered);
          final p = ctrl.activePortal;
          if (p == null) return;
          if (hovered) {
            ctrl.schedulePortalHealthCheck(p);
          } else if (!_portalToolFocused) {
            ctrl.cancelPortalHealthCheck(p.key);
          }
        },
        // Animate layout only. Lerping BoxDecoration border+radius together
        // hits Flutter's assert (borderRadius requires uniform BorderSide.color).
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: _kSearchCollapsed,
          constraints: BoxConstraints(minWidth: minW, maxWidth: maxW),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          decoration: BoxDecoration(
            color: tvFocused
                ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
                : showHighlight
                    ? Colors.white.withValues(alpha: selected ? 0.14 : 0.10)
                    : Colors.white.withValues(alpha: 0.06),
            borderRadius: chipRadius,
            border: Border.fromBorderSide(side),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (portal != null)
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    widthFactor: revealSeats ? 1 : 0,
                    child: Padding(
                      padding: EdgeInsets.only(right: compact ? 6 : 8),
                      child: _portalButtonSeats(
                        active: portal.activeConnections,
                        max: portal.maxConnections,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 14,
                height: 14,
                child: Center(
                  child: portal != null
                      ? _portalButtonStatusDot(
                          checking: checking,
                          health: health,
                        )
                      : Icon(
                          Icons.add_link_rounded,
                          size: 16,
                          color: iptvFocusFg(
                            IptvShellStyle.accent,
                            active: active,
                            tvFocused: tvFocused,
                          ),
                        ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _portalLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: iptvFocusFg(
                        Colors.white,
                        active: active,
                        tvFocused: tvFocused,
                      ),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  selected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
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
      ),
    );
  }

  Widget _portalButtonStatusDot({
    required bool checking,
    required bool? health,
  }) {
    if (checking) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white54,
        ),
      );
    }
    final color = health == true
        ? playerSourceStatusColor(PlayerSourceStatus.active)
        : health == false
            ? playerSourceStatusColor(PlayerSourceStatus.failed)
            : playerSourceStatusColor(PlayerSourceStatus.unchecked);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _portalButtonSeats({required String active, required String max}) {
    final used = active.trim().isEmpty ? '0' : active.trim();
    final cap = max.trim().isEmpty ? '?' : max.trim();
    final activeN = int.tryParse(used);
    final maxN = int.tryParse(cap);
    final full = activeN != null && maxN != null && maxN > 0 && activeN >= maxN;
    final color = full ? const Color(0xFFFBBF24) : const Color(0xFF22C55E);
    return Text(
      '$used/$cap',
      maxLines: 1,
      style: GoogleFonts.plusJakartaSans(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}

class _IptvLiveSortMenu extends StatefulWidget {
  const _IptvLiveSortMenu({
    required this.categorySort,
    required this.contentSort,
    required this.onCategorySort,
    required this.onContentSort,
  });

  final IptvCatalogSort categorySort;
  final IptvCatalogSort contentSort;
  final ValueChanged<IptvCatalogSort> onCategorySort;
  final ValueChanged<IptvCatalogSort> onContentSort;

  @override
  State<_IptvLiveSortMenu> createState() => _IptvLiveSortMenuState();
}

class _IptvLiveSortMenuState extends State<_IptvLiveSortMenu> {
  static const _options = <(IptvCatalogSort, String, IconData)>[
    (
      IptvCatalogSort.playlist,
      'Playlist Order',
      Icons.format_list_numbered_rounded,
    ),
    (IptvCatalogSort.nameAsc, 'Name (A–Z)', Icons.sort_by_alpha_rounded),
    (IptvCatalogSort.nameDesc, 'Name (Z–A)', Icons.sort_by_alpha_rounded),
  ];

  late IptvCatalogSort _categorySort = widget.categorySort;
  late IptvCatalogSort _contentSort = widget.contentSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.cardRadius),
        hoverColor: ForjaShellColors.inkHover,
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
        onTap: onTap,
        borderRadius: PlayerPopupTokens.cardRadius,
        showFocusBorder: true,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        child: row,
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
                  browseHintStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  caretHeight: 18,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search channels or categories…',
                    hintStyle: GoogleFonts.plusJakartaSans(
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

/// Shelf tab - section gradient when selected / hovered.
/// Hover sequence: color paints first, then the tab expands to reveal reload.
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
  /// Pause after color so expand never leads the hover feedback.
  static const _colorThenExpandDelay = Duration(milliseconds: 90);
  static const _expandDuration = Duration(milliseconds: 200);

  bool _hover = false;
  bool _focused = false;
  bool _reloadArmed = false;
  Timer? _revealTimer;

  bool get _tv => iptvUseTvFocus(context);

  /// Section color on mouse hover and D-pad focus (TV included).
  bool get _paintActive => _hover || _focused;

  /// Reload chip expand is mouse / desktop-keyboard only - not TV focus.
  bool get _expandActive => _hover || (_focused && !_tv);

  bool get _revealReload => _expandActive && _reloadArmed;

  void _setHover(bool value) {
    if (_hover == value) return;
    setState(() {
      _hover = value;
      _syncReveal();
    });
  }

  void _setFocused(bool value) {
    if (_focused == value) return;
    setState(() {
      _focused = value;
      _syncReveal();
    });
  }

  /// Color is applied immediately in [build]; expand arms after a short delay.
  void _syncReveal() {
    if (_expandActive) {
      if (_reloadArmed) return;
      _revealTimer?.cancel();
      _revealTimer = Timer(_colorThenExpandDelay, () {
        if (mounted && _expandActive) setState(() => _reloadArmed = true);
      });
    } else {
      _revealTimer?.cancel();
      _revealTimer = null;
      if (_reloadArmed) _reloadArmed = false;
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

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
    // Instant color - AnimatedContainer gradient lerp often lags layout
    // expand, which made the tab feel like it scaled before tinting.
    final showColor = widget.selected || _paintActive;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Container(
        height: _kShelfTabHeight,
        decoration: BoxDecoration(
          gradient: showColor
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.spec.shelfGradientColors,
                )
              : null,
          color: showColor ? null : Colors.transparent,
          borderRadius: _radius,
          boxShadow: widget.selected && showColor
              ? [
                  BoxShadow(
                    color: widget.spec.shelfGradientColors.first
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full tab height is the hit target - not just the icon/label.
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
              onFocusChange: _setFocused,
              child: SizedBox(
                height: _kShelfTabHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        widget.spec.icon,
                        size: 16,
                        color: showColor ? Colors.white : Colors.white60,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.spec.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: showColor ? Colors.white : Colors.white60,
                          fontSize: 12.5,
                          fontWeight: showColor
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: _expandDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: _revealReload ? 1 : 0,
                child: SizedBox(
                  height: _kShelfTabHeight,
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
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Tooltip(
                          message: 'Reload ${widget.spec.label}',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveLayoutToggleSlot extends StatelessWidget {
  const _LiveLayoutToggleSlot({
    required this.icon,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(_kShelfTabHeight / 2);
    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.0,
      pressScale: 0.96,
      builder: (hover, pressed) {
        final active = selected || hover || pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: _kShelfTabHeight,
          height: _kShelfTabHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: pressed ? 0.16 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? r : Radius.zero,
              right: isLast ? r : Radius.zero,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : Colors.white60,
          ),
        );
      },
    );
  }
}
