part of 'iptv_catalog_workspace.dart';

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
  static const _portalRowHeight = 98.0;
  /// Keep a tall cache so D-pad ↑/↓ finds the next FocusNode already mounted.
  static const _scrollCacheRows = 14;
  /// Edge margin when nudging the focused row into view (matches channel guide).
  static const _listFocusMargin = 8.0;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _panelFocus = FocusNode();
  final ScrollController _listScroll = ScrollController();
  String _query = '';
  bool _searchOpen = false;
  bool _didFocusHeaderOnOpen = false;
  String? _scrolledToActiveKey;
  int? _scrolledToActiveIndex;
  /// Row the user last reached with ↑/↓ — ↓ from the header returns here
  /// instead of snapping back to the active portal.
  int? _lastFocusedPortalIndex;
  late Set<String> _knownPortalKeys;

  @override
  void initState() {
    super.initState();
    _knownPortalKeys = {for (final v in widget.ctrl.verified) v.key};
    widget.ctrl.addListener(_onCtrlChanged);
    if (widget.ctrl.portalPanelOpen) {
      _didFocusHeaderOnOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusPanelHeader();
        _scrollToActivePortal();
      });
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    final currentKeys = {for (final v in widget.ctrl.verified) v.key};
    if (widget.ctrl.portalPanelOpen) {
      if (!_didFocusHeaderOnOpen && !_searchOpen) {
        _didFocusHeaderOnOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _focusPanelHeader());
      }
      // Portal health probes notify while the user scrolls — never move the
      // viewport out from under a focused row.
      final listFocused = iptvRowHasFocus('portals');
      final activeKey = widget.ctrl.activePortal?.key;
      final activeIndex = activeKey == null
          ? -1
          : _filtered.indexWhere((v) => v.key == activeKey);
      // Same active key can move after favorite / deal / scrape sort — keep it
      // in view so header ↓ can focus a mounted row.
      final willScrollActive = activeKey != null &&
          !listFocused &&
          (activeKey != _scrolledToActiveKey ||
              activeIndex != _scrolledToActiveIndex);
      if (willScrollActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActivePortal());
      }
      final added = currentKeys.difference(_knownPortalKeys);
      _knownPortalKeys = currentKeys;
      if (added.isNotEmpty && _query.trim().isEmpty && !listFocused) {
        // Sorted list puts newest non-favorites first after favorites - scroll
        // to the first newly added key in that order (e.g. scrape hits).
        String? scrollKey;
        for (final v in widget.ctrl.verified) {
          if (added.contains(v.key)) {
            scrollKey = v.key;
            break;
          }
        }
        // Skip if active-portal scroll already covers this key (manual/share add).
        if (scrollKey != null &&
            !(willScrollActive && scrollKey == activeKey)) {
          final key = scrollKey;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToPortalKey(key, animate: true),
          );
        }
      }
    } else {
      _knownPortalKeys = currentKeys;
      _didFocusHeaderOnOpen = false;
      _scrolledToActiveKey = null;
      _scrolledToActiveIndex = null;
      _lastFocusedPortalIndex = null;
    }
  }

  void _focusPanelHeader() {
    if (!mounted || !widget.ctrl.portalPanelOpen || _searchOpen) return;
    // Only the open handoff may claim focus — a later notify must not pull the
    // user out of the list they are scrolling.
    if (_panelFocus.hasFocus) return;
    // Prefer Add (+), which is the last header action.
    final addIndex = _portalHeaderAddIndex();
    if (iptvFocusRowItem('iptv-portal-header', addIndex)) return;
    iptvFocusRowItem('iptv-portal-header', 0);
  }

  /// Search (0) · optional Scrape · optional Deal · Add (last).
  int _portalHeaderAddIndex() {
    var idx = 1;
    if (AccountFeatures.instance.isIptvScrapeEnabled) idx++;
    if (AccountFeatures.instance.isDealPortalEnabled &&
        SyncService.instance.isSignedIn) {
      idx++;
    }
    return idx;
  }

  void _focusPortalsFromHeader() {
    if (_filtered.isEmpty) return;
    // onDownEdge always claims the key — must land focus or retry until a
    // portal row is mounted (exact active index often missing after reorder).
    var tries = 0;
    var scrolledFor = -1;
    void attempt() {
      if (!mounted || !widget.ctrl.portalPanelOpen) return;
      final all = _filtered;
      if (all.isEmpty) return;
      final index = _portalEntryIndex(all);
      if (ShellTvFocusCoordinator.focusRowItemExact('iptv', 'portals', index)) {
        _lastFocusedPortalIndex = index;
        return;
      }
      if (scrolledFor != index) {
        _jumpPortalListToIndex(index);
        scrolledFor = index;
        tries++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      // Node still missing after scroll — nudge again (same as channel restore).
      scrolledFor = -1;
      if (tries++ < 16) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      // Last resort: any mounted portal (usually first) so ↓ never traps.
      iptvFocusRowItem('portals', 0);
    }

    attempt();
  }

  /// Row ↓ from the header lands on: where the user left the list, else the
  /// active (playing) portal on first entry.
  int _portalEntryIndex(List<VerifiedPortal> all) {
    final last = _lastFocusedPortalIndex;
    if (last != null && last >= 0 && last < all.length) return last;
    return iptvActivePortalFocusIndex(widget.ctrl, portals: all);
  }

  /// D-pad ↑/↓: focus neighbor. Jump-then-retry when the lazy builder has not
  /// mounted that row yet (long scraped lists).
  void _focusPortalAt(int index) {
    if (!mounted || !widget.ctrl.portalPanelOpen) return;
    final total = _filtered.length;
    if (index < 0 || index >= total) return;
    _lastFocusedPortalIndex = index;
    if (ShellTvFocusCoordinator.focusRowItemExact('iptv', 'portals', index)) {
      return;
    }
    _jumpPortalListToIndex(index);
    var tries = 0;
    void attempt() {
      if (!mounted || !widget.ctrl.portalPanelOpen) return;
      if (ShellTvFocusCoordinator.focusRowItemExact('iptv', 'portals', index)) {
        return;
      }
      _jumpPortalListToIndex(index);
      if (tries++ < 12) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  /// Instant jump so [index] is mountable — ListView.builder only builds a
  /// window around the viewport.
  void _jumpPortalListToIndex(int index) {
    if (!_listScroll.hasClients || index < 0) return;
    final position = _listScroll.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final itemTop = index * _portalRowHeight;
    final itemBottom = itemTop + _portalRowHeight;
    final viewTop = position.pixels;
    final viewBottom = viewTop + viewport;
    double? target;
    if (itemTop < viewTop + _listFocusMargin) {
      target = itemTop - _listFocusMargin;
    } else if (itemBottom > viewBottom - _listFocusMargin) {
      target = itemBottom - viewport + _listFocusMargin;
    }
    if (target == null) return;
    _listScroll.jumpTo(
      target.clamp(0.0, position.maxScrollExtent),
    );
  }

  void _scrollToActivePortal() {
    final activeKey = widget.ctrl.activePortal?.key;
    if (activeKey == null) return;
    final index = _filtered.indexWhere((v) => v.key == activeKey);
    _scrollToPortalKey(activeKey, animate: false);
    _scrolledToActiveKey = activeKey;
    _scrolledToActiveIndex = index >= 0 ? index : null;
  }

  void _scrollToPortalKey(String key, {required bool animate}) {
    if (!mounted || !widget.ctrl.portalPanelOpen) return;
    if (_query.trim().isNotEmpty) return;
    final index = _filtered.indexWhere((v) => v.key == key);
    if (index < 0) return;
    if (!_listScroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToPortalKey(key, animate: animate),
      );
      return;
    }
    final target = (index * _portalRowHeight).clamp(
      0.0,
      _listScroll.position.maxScrollExtent,
    );
    if (animate && !ShellTokens.isAndroidTvDevice) {
      _listScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _listScroll.jumpTo(target);
    }
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
    _lastFocusedPortalIndex = null;
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
      return v.displayLabel.toLowerCase().contains(q) ||
          v.label.toLowerCase().contains(q) ||
          v.name.toLowerCase().contains(q) ||
          v.portal.url.toLowerCase().contains(q) ||
          v.portal.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final list = _filtered;
    final activeKey = ctrl.activePortal?.key;
    final totalCount = list.length;

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
                      onChanged: (v) {
                        _lastFocusedPortalIndex = null;
                        setState(() => _query = v);
                      },
                      onEscape: _closeSearch,
                      browsePlaceholder: 'Search portals…',
                      browseHintStyle: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      caretHeight: 18,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search portals…',
                        hintStyle: GoogleFonts.plusJakartaSans(
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
                                  _lastFocusedPortalIndex = null;
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
                      ? '$totalCount portal${totalCount == 1 ? '' : 's'}'
                      : ctrl.statusText,
                  style: GoogleFonts.plusJakartaSans(
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
    return ListenableBuilder(
      listenable: AccountFeatures.instance.revision,
      builder: (context, _) {
        final canScrape = AccountFeatures.instance.isIptvScrapeEnabled;
        final canDeal = AccountFeatures.instance.isDealPortalEnabled &&
            SyncService.instance.isSignedIn;
        final credits = AccountFeatures.instance.iptvCredits;
        // search (+ scrape?) (+ deal?) + add
        var headerCount = 2;
        if (canScrape) headerCount++;
        if (canDeal) headerCount++;
        var idx = 0;
        final searchIndex = idx++;
        final scrapeIndex = canScrape ? idx++ : -1;
        final dealIndex = canDeal ? idx++ : -1;
        final addIndex = idx;
        return iptvCatalogRow(
          rowId: 'iptv-portal-header',
          sortOrder: 0,
          itemCount: headerCount,
          child: Container(
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
                if (canDeal) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$credits cr',
                    style: TextStyle(
                      color: credits > 0
                          ? IptvShellStyle.accent
                          : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                IptvIconAction(
                  tooltip: _searchOpen ? 'Close search' : 'Search portals',
                  onPressed: _toggleSearch,
                  icon:
                      _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  color: _searchOpen ? IptvShellStyle.accent : null,
                  tvRowId: 'iptv-portal-header',
                  tvItemIndex: searchIndex,
                  tvZone: ShellTvZone.topBar,
                  onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                  onDownEdge: _focusPortalsFromHeader,
                  onRightEdge: () => iptvFocusRowItem(
                    'iptv-portal-header',
                    canScrape
                        ? scrapeIndex
                        : (canDeal ? dealIndex : addIndex),
                  ),
                ),
                if (canScrape)
                  IptvIconAction(
                    tooltip:
                        ctrl.isScraping ? 'Stop scrape' : 'Scrape portals',
                    onPressed:
                        ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
                    icon: ctrl.isScraping
                        ? Icons.stop_circle_rounded
                        : Icons.travel_explore_rounded,
                    color: ctrl.isScraping ? IptvShellStyle.accent : null,
                    tvRowId: 'iptv-portal-header',
                    tvItemIndex: scrapeIndex,
                    tvZone: ShellTvZone.topBar,
                    onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                    onDownEdge: _focusPortalsFromHeader,
                    onLeftEdge: () =>
                        iptvFocusRowItem('iptv-portal-header', searchIndex),
                    onRightEdge: () => iptvFocusRowItem(
                      'iptv-portal-header',
                      canDeal ? dealIndex : addIndex,
                    ),
                  ),
                if (canDeal)
                  IptvIconAction(
                    tooltip: credits > 0
                        ? 'Deal portals from pool ($credits credits)'
                        : 'Deal portals (no credits)',
                    onPressed: () {
                      if (credits < 1) {
                        ForjaToast.warning('No Deal credits left');
                        return;
                      }
                      unawaited(ctrl.dealFromPool());
                    },
                    icon: Icons.casino_rounded,
                    color: credits > 0 ? IptvShellStyle.accent : null,
                    tvRowId: 'iptv-portal-header',
                    tvItemIndex: dealIndex,
                    tvZone: ShellTvZone.topBar,
                    onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                    onDownEdge: _focusPortalsFromHeader,
                    onLeftEdge: () => iptvFocusRowItem(
                      'iptv-portal-header',
                      canScrape ? scrapeIndex : searchIndex,
                    ),
                    onRightEdge: () =>
                        iptvFocusRowItem('iptv-portal-header', addIndex),
                  ),
                IptvIconAction(
                  tooltip: AccountFeatures.instance.canAddIptvPortal(
                        ctrl.verified.length,
                      )
                      ? 'Add portal'
                      : 'Portal limit reached (${AccountFeatures.instance.iptvPortalLimitLabel()})',
                  onPressed: () {
                    if (!AccountFeatures.instance.canAddIptvPortal(
                      ctrl.verified.length,
                    )) {
                      ForjaToast.warning(
                        AccountFeatures.instance
                            .iptvPortalLimitReachedMessage(),
                      );
                      return;
                    }
                    _showAddDialog(context);
                  },
                  icon: Icons.add_rounded,
                  tvRowId: 'iptv-portal-header',
                  tvItemIndex: addIndex,
                  tvZone: ShellTvZone.topBar,
                  onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                  onDownEdge: _focusPortalsFromHeader,
                  onLeftEdge: () => iptvFocusRowItem(
                    'iptv-portal-header',
                    canDeal
                        ? dealIndex
                        : (canScrape ? scrapeIndex : searchIndex),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return ListenableBuilder(
      listenable: AccountFeatures.instance.revision,
      builder: (context, _) {
        final canScrape = AccountFeatures.instance.isIptvScrapeEnabled;
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
                  canScrape
                      ? 'Scrape or add a portal to browse channels.'
                      : 'Add a portal to browse channels.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortalList(
    List<VerifiedPortal> list,
    String? activeKey,
  ) {
    final ctrl = widget.ctrl;
    final last = list.length - 1;
    return iptvCatalogRow(
      rowId: 'portals',
      sortOrder: 2,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
      child: IptvTvScrollbar(
        controller: _listScroll,
        child: ListView.builder(
          controller: _listScroll,
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          itemExtent: _portalRowHeight,
          // Warm off-screen neighbors so D-pad ↑/↓ usually hits a mounted node.
          scrollCacheExtent: ScrollCacheExtent.pixels(
            _portalRowHeight * _scrollCacheRows,
          ),
          addAutomaticKeepAlives: false,
          itemCount: list.length,
          itemBuilder: (_, i) {
            final v = list[i];
            return RepaintBoundary(
              key: ValueKey<String>(v.key),
              child: _PortalHoverTile(
                portal: v,
                ctrl: ctrl,
                isActive: v.key == activeKey,
                listIndex: i,
                onUpEdge: i == 0
                    ? () => iptvFocusRowItem(
                          'iptv-portal-header',
                          _portalHeaderAddIndex(),
                        )
                    : () => _focusPortalAt(i - 1),
                onDownEdge:
                    i >= last ? null : () => _focusPortalAt(i + 1),
                onEdit: () => _showPortalDialog(context, existing: v),
              ),
            );
          },
        ),
      ),
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
