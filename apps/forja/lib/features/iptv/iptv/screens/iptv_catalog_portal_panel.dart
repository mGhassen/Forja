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

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _panelFocus = FocusNode();
  final ScrollController _listScroll = ScrollController();
  String _query = '';
  bool _searchOpen = false;
  bool _didFocusHeaderOnOpen = false;
  String? _scrolledToActiveKey;
  late Set<String> _knownPortalKeys;

  @override
  void initState() {
    super.initState();
    _knownPortalKeys = {for (final v in widget.ctrl.verified) v.key};
    widget.ctrl.addListener(_onCtrlChanged);
    if (widget.ctrl.portalPanelOpen) {
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
      final activeKey = widget.ctrl.activePortal?.key;
      final willScrollActive =
          activeKey != null && activeKey != _scrolledToActiveKey;
      if (willScrollActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActivePortal());
      }
      final added = currentKeys.difference(_knownPortalKeys);
      _knownPortalKeys = currentKeys;
      if (added.isNotEmpty && _query.trim().isEmpty) {
        // Sorted list puts newest non-favorites first after favorites — scroll
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
    }
  }

  void _focusPanelHeader() {
    if (!mounted || !widget.ctrl.portalPanelOpen || _searchOpen) return;
    iptvFocusRowItem('iptv-portal-header', 2);
  }

  void _scrollToActivePortal() {
    final activeKey = widget.ctrl.activePortal?.key;
    if (activeKey == null) return;
    _scrollToPortalKey(activeKey, animate: false);
    _scrolledToActiveKey = activeKey;
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
    if (animate) {
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
        iptvSyncRow(
          rowId: 'iptv-portal-header',
          sortOrder: 0,
          itemCount: headerCount,
        );
        var idx = 0;
        final searchIndex = idx++;
        final scrapeIndex = canScrape ? idx++ : -1;
        final dealIndex = canDeal ? idx++ : -1;
        final addIndex = idx;
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
                icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: _searchOpen ? IptvShellStyle.accent : null,
                tvRowId: 'iptv-portal-header',
                tvItemIndex: searchIndex,
                tvZone: ShellTvZone.topBar,
                onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                onDownEdge: () => iptvFocusRowItem('portals', 0),
                onRightEdge: () => iptvFocusRowItem(
                  'iptv-portal-header',
                  canScrape ? scrapeIndex : (canDeal ? dealIndex : addIndex),
                ),
              ),
              if (canScrape)
                IptvIconAction(
                  tooltip: ctrl.isScraping ? 'Stop scrape' : 'Scrape portals',
                  onPressed: ctrl.isScraping ? ctrl.stopScrape : ctrl.scrape,
                  icon: ctrl.isScraping
                      ? Icons.stop_circle_rounded
                      : Icons.travel_explore_rounded,
                  color: ctrl.isScraping ? IptvShellStyle.accent : null,
                  tvRowId: 'iptv-portal-header',
                  tvItemIndex: scrapeIndex,
                  tvZone: ShellTvZone.topBar,
                  onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                  onDownEdge: () => iptvFocusRowItem('portals', 0),
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
                  onPressed: credits < 1
                      ? null
                      : () => unawaited(ctrl.dealFromPool()),
                  icon: Icons.casino_rounded,
                  color: credits > 0 ? IptvShellStyle.accent : null,
                  tvRowId: 'iptv-portal-header',
                  tvItemIndex: dealIndex,
                  tvZone: ShellTvZone.topBar,
                  onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                  onDownEdge: () => iptvFocusRowItem('portals', 0),
                  onLeftEdge: () => iptvFocusRowItem(
                    'iptv-portal-header',
                    canScrape ? scrapeIndex : searchIndex,
                  ),
                  onRightEdge: () =>
                      iptvFocusRowItem('iptv-portal-header', addIndex),
                ),
              IptvIconAction(
                tooltip: 'Add portal',
                onPressed: () => _showAddDialog(context),
                icon: Icons.add_rounded,
                tvRowId: 'iptv-portal-header',
                tvItemIndex: addIndex,
                tvZone: ShellTvZone.topBar,
                onUpEdge: () => iptvFocusRowItem('iptv-top-tools', 1),
                onDownEdge: () => iptvFocusRowItem('portals', 0),
                onLeftEdge: () => iptvFocusRowItem(
                  'iptv-portal-header',
                  canDeal
                      ? dealIndex
                      : (canScrape ? scrapeIndex : searchIndex),
                ),
              ),
            ],
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

  Widget _buildPortalList(List<VerifiedPortal> list, String? activeKey) {
    final ctrl = widget.ctrl;
    iptvSyncRow(
      rowId: 'portals',
      sortOrder: 2,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
    );
    return ListView.builder(
      controller: _listScroll,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      itemExtent: _portalRowHeight,
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
