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
                  style: GoogleFonts.plusJakartaSans(
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

/// Shelf tab — section gradient when selected.
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

  bool get _revealReload =>
      widget.selected && (_hover || (_focused && !_tv));

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
        duration: Duration.zero,
        curve: Curves.easeOutCubic,
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
                      style: GoogleFonts.plusJakartaSans(
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
          ],
        ),
      ),
    );
  }
}

