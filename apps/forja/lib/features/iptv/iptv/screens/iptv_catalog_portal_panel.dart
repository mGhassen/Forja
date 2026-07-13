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
