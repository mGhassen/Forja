part of 'iptv_pt_screen.dart';

class _BrowserView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  final bool wide;
  final bool embedded;
  const _BrowserView({
    required this.ctrl,
    required this.compact,
    required this.wide,
    this.embedded = false,
  });

  @override
  State<_BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<_BrowserView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _openPortalFocus = FocusNode(debugLabel: 'iptv-open-portal');
  Timer? _scrollSettleTimer;
  bool _didInitialFocus = false;
  bool _wasLoading = false;
  bool _wasPortalPanelOpen = false;

  bool get _searchOpen => widget.ctrl.browserSearchOpen;
  bool get _needsPortal => widget.ctrl.activePortal == null;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.ctrl.browserSearch;
    _wasLoading = widget.ctrl.isLoading;
    _wasPortalPanelOpen = widget.ctrl.portalPanelOpen;
    widget.ctrl.addListener(_onCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInitialFocus());
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    _scrollSettleTimer?.cancel();
    _searchFocus.dispose();
    _openPortalFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    final loading = widget.ctrl.isLoading;
    final finishedLoad = _wasLoading && !loading;
    _wasLoading = loading;
    final panelOpen = widget.ctrl.portalPanelOpen;
    final panelClosed = _wasPortalPanelOpen && !panelOpen;
    _wasPortalPanelOpen = panelOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (panelClosed && !_needsPortal) {
        _focusCatalogGroup();
        return;
      }
      if (_needsPortal) {
        // Don't steal focus while the portals panel is open.
        if (!widget.ctrl.portalPanelOpen && !_openPortalFocus.hasFocus) {
          _focusOpenPortalButton();
        }
        return;
      }
      if (widget.ctrl.portalPanelOpen) return;
      if (loading) return;
      if (finishedLoad || !_didInitialFocus) {
        if (widget.ctrl.categories.isNotEmpty ||
            widget.ctrl.browserAllStreams.isNotEmpty) {
          _focusCatalogGroup();
        }
      }
    });
  }

  void _syncInitialFocus() {
    if (!mounted) return;
    if (_needsPortal) {
      _focusOpenPortalButton();
    } else if (!widget.ctrl.isLoading) {
      _focusCatalogGroup();
    }
  }

  void _focusOpenPortalButton() {
    if (!_openPortalFocus.canRequestFocus) return;
    _openPortalFocus.requestFocus();
    _didInitialFocus = false;
  }

  void _focusCatalogGroup() {
    if (!iptvFocusCatalogGroupRow(0)) {
      if (widget.ctrl.browserSidebarCategories.isEmpty) {
        iptvFocusRowItem('browser-streams', 0);
      }
    }
    _didInitialFocus = true;
  }

  @override
  void didUpdateWidget(covariant _BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ctrl.browserSearchOpen && !oldWidget.ctrl.browserSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    if (!widget.ctrl.browserSearchOpen && _searchCtrl.text.isNotEmpty) {
      _searchCtrl.clear();
    }
  }

  void _openSearch() {
    widget.ctrl.openBrowserSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    widget.ctrl.closeBrowserSearch();
    _searchCtrl.clear();
    _searchFocus.unfocus();
    if (mounted) setState(() {});
  }

  void _clearSearchQuery() {
    _searchCtrl.clear();
    widget.ctrl.setBrowserSearch('');
    if (mounted) setState(() {});
  }

  void toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _toggleSearch() => toggleSearch();

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _scrollSettleTimer?.cancel();
      widget.ctrl.cancelAllLazyChecks();
    } else if (n is ScrollEndNotification) {
      _scrollSettleTimer?.cancel();
      _scrollSettleTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() {});
      });
    }
    return false;
  }

  String get _sectionTitle {
    switch (widget.ctrl.activeSection) {
      case IptvSection.live:
        return 'Live TV';
      case IptvSection.vod:
        return 'Movies';
      case IptvSection.series:
        return 'Series';
      default:
        return 'Browse';
    }
  }

  List<IptvCategory> get _filteredCategories => widget.ctrl.browserSidebarCategories;

  List<IptvStream> get _filteredStreams {
    final ctrl = widget.ctrl;
    var s = ctrl.browserAllStreams;
    final cat = ctrl.browserSelectedCategoryId;
    final q = ctrl.browserSearch.trim().toLowerCase();

    if (q.isNotEmpty) {
      // Search is global across categories AND matches by stream name OR by
      // the stream's category name. Lookup table built once per filter pass.
      final catNameById = <String, String>{
        for (final c in ctrl.categories) c.id: c.name.toLowerCase(),
      };
      s = s.where((x) {
        if (x.name.toLowerCase().contains(q)) return true;
        final cn = catNameById[x.categoryId];
        return cn != null && cn.contains(q);
      }).toList();
    } else if (cat != null && cat.isNotEmpty) {
      s = s.where((x) => x.categoryId == cat).toList();
    }

    if (ctrl.activeSection == IptvSection.live &&
        ctrl.liveOnly &&
        ctrl.aliveStreamIds.isNotEmpty) {
      s = s.where((x) => ctrl.aliveStreamIds.contains(x.streamId)).toList();
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    if (ctrl.activePortal == null) {
      return _buildChoosePortalEmpty(context);
    }

    final body = Column(
      children: [
        if (!widget.embedded)
          _PtAppBar(
            title: _sectionTitle,
            subtitle: ctrl.activePortal?.displayLabel,
            onBack: ctrl.back,
            actions: [
              IptvIconAction(
                tooltip: _searchOpen ? 'Close search' : 'Search channels',
                onPressed: _toggleSearch,
                icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: _searchOpen ? IptvShellStyle.accent : null,
              ),
              if (ctrl.activeSection != null) ...[
                IptvIconAction(
                  tooltip: 'Reload ${_sectionTitle}',
                  onPressed: ctrl.isLoading
                      ? null
                      : () => ctrl.reloadSection(ctrl.activeSection!),
                  icon: Icons.refresh_rounded,
                ),
                if (ctrl.activeSection == IptvSection.live)
                  IptvIconAction(
                    tooltip: ctrl.isVerifyingAlive
                        ? 'Stop alive check'
                        : 'Re-check all streams',
                    onPressed: ctrl.isVerifyingAlive
                        ? ctrl.stopAliveCheck
                        : ctrl.recheckAlive,
                    icon: ctrl.isVerifyingAlive
                        ? Icons.stop_circle_rounded
                        : Icons.verified_outlined,
                  ),
              ],
            ],
          ),
        if (!widget.embedded)
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _searchOpen ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: _buildOverlaySearchBar(),
            ),
          ),
        if (ctrl.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              ctrl.error!,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444)),
            ),
          ),
        Expanded(
          child: ctrl.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: IptvShellStyle.accent,
                  ),
                )
              : _buildContent(),
        ),
      ],
    );

    if (widget.embedded) return body;
    return SafeArea(child: body);
  }

  Widget _buildChoosePortalEmpty(BuildContext context) {
    iptvSyncRow(rowId: 'iptv-open-portal', sortOrder: 0, itemCount: 1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt_rounded,
              size: 72,
              color: IptvShellStyle.accent,
            ),
            const SizedBox(height: 20),
            Text(
              'Choose a portal',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a provider to browse Live TV, Movies, and Series.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 28),
            IptvPrimaryButton(
              icon: Icons.dns_rounded,
              label: 'Open portal',
              focusNode: _openPortalFocus,
              tvRowId: 'iptv-open-portal',
              tvItemIndex: 0,
              onPressed: widget.ctrl.openPortalPanel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlaySearchBar() {
    final query = widget.ctrl.browserSearch;
    return ShellSearchBar(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      query: query,
      wrapSafeArea: false,
      hintText: 'Search channels or categories…',
      onChanged: widget.ctrl.setBrowserSearch,
      onClear: _clearSearchQuery,
      onEscape: _closeSearch,
      clearSuffix: query.isNotEmpty
          ? iptvCloseButton(context, onTap: _clearSearchQuery)
          : null,
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final categoryWidth = widget.compact
            ? (constraints.maxWidth * 0.34).clamp(132.0, 184.0)
            : (widget.wide ? 240.0 : 200.0);

        return Row(
          children: [
            SizedBox(
              width: categoryWidth,
              child: _buildCategorySidebar(compact: widget.compact),
            ),
            Expanded(
              child: widget.compact ? _buildStreamRows() : _buildStreamGrid(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySidebar({bool compact = false}) {
    final ctrl = widget.ctrl;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Builder(
        builder: (_) {
          final cats = _filteredCategories;
          iptvSyncRow(
            rowId: 'browser-categories',
            sortOrder: 2,
            itemCount: cats.length,
            orientation: ShellTvRowOrientation.vertical,
            onFocusUp: () => iptvFocusRowItem(
              'iptv-sections',
              iptvActiveSectionShelfIndex(ctrl),
            ),
          );
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cats.length,
            itemBuilder: (_, i) {
              final c = cats[i];
              final selected = c.id == ctrl.browserSelectedCategoryId;
              return _CategorySidebarRow(
                label: c.name.isEmpty ? 'Uncategorized' : c.name,
                selected: selected,
                compact: compact,
                listIndex: i,
                onTap: () => ctrl.selectBrowserCategory(c.id),
                onUpEdge: i == 0
                    ? () => iptvFocusRowItem(
                        'iptv-sections',
                        iptvActiveSectionShelfIndex(ctrl),
                      )
                    : null,
                onRightEdge: () => iptvFocusRowItem('browser-streams'),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStreamGrid() {
    final list = _filteredStreams;
    if (list.isEmpty) {
      return _buildStreamsEmpty();
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final tv = ShellScope.metricsOf(ctx).usesTvDensity;
        final cardW = shellMovieCardWidth(ctx);
        final cardH = shellMovieCardHeight(ctx);
        final gap = tv ? shellMovieCardRowGap(ctx) : 10.0;
        final hPad = 24.0;
        final cross = tv
            ? ((c.maxWidth - hPad + gap) / (cardW + gap)).floor().clamp(1, 24)
            : (c.maxWidth ~/ 180).clamp(2, 8);
        iptvSyncRow(
          rowId: 'browser-streams',
          sortOrder: 3,
          itemCount: list.length,
          onFocusUp: () => iptvFocusRowItem(
            'iptv-sections',
            iptvActiveSectionShelfIndex(widget.ctrl),
          ),
        );
        final grid = GridView.builder(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
          gridDelegate: tv
              ? SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: cardW,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: cardW / cardH,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: 0.9,
                ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final stream = list[i];
            return _StreamCard(
              stream: stream,
              ctrl: widget.ctrl,
              gridIndex: i,
              gridColumns: cross,
              onUpEdge: i < cross
                  ? iptvStreamUpEdge(
                      widget.ctrl,
                      index: i,
                      columns: cross,
                    )
                  : null,
              onRightEdge:
                  widget.ctrl.portalPanelOpen && (i % cross) == cross - 1
                      ? () => iptvFocusRowItem('portals', 0)
                      : null,
              onLeftEdge: i % cross == 0
                  ? iptvStreamLeftEdge(widget.ctrl, stream)
                  : null,
              onTap: () => _onStreamTap(stream),
            );
          },
        );
        if (!_LiveHealthProbe.usesScrollDebounce(ctx)) return grid;
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: grid,
        );
      },
    );
  }

  Widget _buildStreamRows() {
    final ctrl = widget.ctrl;
    final list = _filteredStreams;
    if (list.isEmpty) return _buildStreamsEmpty();

    final categoryNames = {for (final c in ctrl.categories) c.id: c.name};

    iptvSyncRow(
      rowId: 'browser-streams',
      sortOrder: 3,
      itemCount: list.length,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: () => iptvFocusRowItem(
        'iptv-sections',
        iptvActiveSectionShelfIndex(ctrl),
      ),
    );

    final rows = ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final stream = list[i];
        return _StreamRowTile(
          stream: stream,
          ctrl: ctrl,
          categoryName: categoryNames[stream.categoryId] ?? '',
          listIndex: i,
          onLeftEdge: iptvStreamLeftEdge(ctrl, stream),
          onRightEdge: ctrl.portalPanelOpen
              ? () => iptvFocusRowItem('portals', 0)
              : null,
          onUpEdge: i == 0
              ? iptvStreamUpEdge(ctrl, index: 0, columns: 1)
              : null,
          onTap: () => _onStreamTap(stream),
        );
      },
    );
    if (!_LiveHealthProbe.usesScrollDebounce(context)) return rows;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: rows,
    );
  }

  Widget _buildStreamsEmpty() {
    final ctrl = widget.ctrl;
    if (ctrl.browserAllStreams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctrl.error ?? 'Failed to load channels — check connection',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Reload',
              onPressed: ctrl.activeSection == null
                  ? null
                  : () => ctrl.reloadSection(ctrl.activeSection!),
            ),
          ],
        ),
      );
    }
    if (ctrl.activeSection == IptvSection.live && ctrl.liveOnly) {
      final msg = ctrl.isVerifyingAlive
          ? 'Checking streams…'
          : 'No alive streams found';
      return Center(
        child: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white60)),
      );
    }
    return Center(
      child: Text(
        'No streams in this view',
        style: GoogleFonts.plusJakartaSans(color: Colors.white60),
      ),
    );
  }

  void _onStreamTap(IptvStream s) {
    final ctrl = widget.ctrl;
    final p = ctrl.activePortal;
    if (p == null) return;
    if (s.kind == 'series') {
      ctrl.openSeries(s);
      return;
    }
    final url = IptvClient.streamUrl(p.portal, s);
    final channelGuide = s.kind == 'live'
        ? IptvChannelGuide.fromXtreamLive(
            portal: p,
            categories: ctrl.categories,
            streams: ctrl.browserAllStreams,
            initialStream: s,
            streamHealth: Map<String, bool>.from(ctrl.streamHealth),
          )
        : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen.singleStream(
          url: url,
          stream: s,
          portalName: p.displayLabel,
          channelGuide: channelGuide,
        ),
      ),
    );
  }
}
