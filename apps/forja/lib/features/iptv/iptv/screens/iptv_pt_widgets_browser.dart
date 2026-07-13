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
            subtitle: ctrl.activePortal?.name,
            onBack: ctrl.back,
            actions: [
              IptvIconAction(
                tooltip: _searchOpen ? 'Close search' : 'Search channels',
                onPressed: _toggleSearch,
                icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: _searchOpen ? IptvShellStyle.accent : null,
              ),
              if (ctrl.activeSection == IptvSection.live) ...[
                IptvIconAction(
                  tooltip: 'Reload channels',
                  onPressed: ctrl.isLoading
                      ? null
                      : () => ctrl.openSection(IptvSection.live),
                  icon: Icons.refresh_rounded,
                ),
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
              style: GoogleFonts.poppins(color: const Color(0xFFEF4444)),
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
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
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
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Reload',
              onPressed: ctrl.activeSection == null
                  ? null
                  : () => ctrl.openSection(ctrl.activeSection!),
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
        child: Text(msg, style: GoogleFonts.poppins(color: Colors.white60)),
      );
    }
    return Center(
      child: Text(
        'No streams in this view',
        style: GoogleFonts.poppins(color: Colors.white60),
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
          portalName: p.name,
          channelGuide: channelGuide,
        ),
      ),
    );
  }
}

class _CategorySidebarRow extends StatefulWidget {
  const _CategorySidebarRow({
    required this.label,
    required this.selected,
    required this.compact,
    required this.listIndex,
    required this.onTap,
    this.onUpEdge,
    this.onRightEdge,
  });

  final String label;
  final bool selected;
  final bool compact;
  final int listIndex;
  final VoidCallback onTap;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_CategorySidebarRow> createState() => _CategorySidebarRowState();
}

class _CategorySidebarRowState extends State<_CategorySidebarRow> {
  bool _focused = false;
  bool _hovered = false;

  bool get _tvFocused => iptvTvFocused(context, focused: _focused);

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final fg = _tvFocused
        ? ForjaShellColors.brandGreen
        : (selected ? Colors.white : Colors.white70);

    return iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 8,
      listIndex: widget.listIndex,
      tvRowId: 'browser-categories',
      tvItemIndex: widget.listIndex,
      onUpEdge: widget.onUpEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 14,
          vertical: widget.compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: _tvFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
              : selected
                  ? IptvShellStyle.accent.withValues(alpha: 0.12)
                  : _active
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _tvFocused
                  ? ForjaShellColors.brandGreen
                  : selected
                      ? IptvShellStyle.accent
                      : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: fg,
            fontSize: widget.compact ? 11 : 12,
            fontWeight: selected || _tvFocused
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _StreamThumbPlayHint extends StatelessWidget {
  const _StreamThumbPlayHint({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: active ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: active ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: ForjaShellColors.brandGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF111827),
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreamCard extends StatefulWidget {
  final IptvStream stream;
  final IptvController ctrl;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  const _StreamCard({
    required this.stream,
    required this.ctrl,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onLeftEdge,
    this.onUpEdge,
    this.onRightEdge,
  });

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _syncLiveProbe(hovered || _focused);
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _syncLiveProbe(focused || _hovered);
  }

  void _syncLiveProbe(bool active) {
    if (widget.stream.kind != 'live') return;
    if (active) {
      widget.ctrl.scheduleLazyCheck(widget.stream);
    } else {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
  }

  Color _surfaceColor(bool active, bool? health) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _borderColor(bool active, bool? health) {
    if (widget.stream.kind != 'live' || health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    if (health) {
      return const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45);
    }
    return const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  void _showEpgSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EpgSheet(stream: widget.stream, ctrl: widget.ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final health = widget.stream.kind == 'live'
            ? widget.ctrl.healthFor(widget.stream.streamId)
            : null;
        final active = _active(context);
        final tv = ShellScope.metricsOf(context).usesTvDensity;
        final column = tv
            ? _buildTvPosterBody(context, health: health, active: active)
            : _buildDefaultBody(context, health: health, active: active);
        final radius = tv ? shellCardBorderRadius(context) : 12.0;
        Widget card = AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: tv ? Colors.transparent : _surfaceColor(active, health),
            borderRadius: BorderRadius.circular(radius),
            border: tv && !active
                ? Border.all(color: Colors.transparent)
                : Border.all(color: _borderColor(active, health)),
          ),
          child: iptvTap(
            context: context,
            onTap: widget.onTap,
            borderRadius: radius,
            scaleOnFocus: 1.0,
            gridIndex: widget.gridIndex,
            gridColumns: widget.gridColumns,
            tvRowId: 'browser-streams',
            tvZone: ShellTvZone.grid,
            onLeftEdge: widget.onLeftEdge,
            onUpEdge: widget.onUpEdge,
            onRightEdge: widget.onRightEdge,
            onFocusChange: _onFocus,
            onHoverChange: _onHover,
            child: column,
          ),
        );

        if (!iptvUseTvFocus(context) &&
            widget.stream.kind == 'live' &&
            widget.ctrl.epgEnabled) {
          card = GestureDetector(
            onLongPress: () => _showEpgSheet(context),
            child: card,
          );
        }

        if (widget.stream.kind != 'live') return card;

        return _LiveHealthProbe(
          stream: widget.stream,
          ctrl: widget.ctrl,
          child: card,
        );
      },
    );
  }

  Widget _buildDefaultBody(
    BuildContext context, {
    required bool? health,
    required bool active,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _streamThumb(),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: active ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              ShellCardPlayOverlay(active: true, visible: active),
              if (health != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _healthDot(health),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Tooltip(
            message: widget.stream.name,
            waitDuration: const Duration(milliseconds: 600),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  widget.stream.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: GoogleFonts.poppins(
                    color: health == false ? Colors.white54 : Colors.white,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.stream.kind == 'live')
          _EpgNowFooter(stream: widget.stream, ctrl: widget.ctrl),
      ],
    );
  }

  Widget _buildTvPosterBody(
    BuildContext context, {
    required bool? health,
    required bool active,
  }) {
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 8).clamp(4.0, 8.0);
    final titleSize = shellHubCardTitleFontSize(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _streamThumb(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.45, 0.8, 1.0],
              ),
            ),
          ),
          ShellCardPlayOverlay(active: true, visible: active),
          if (health != null)
            Positioned(
              top: inset,
              right: inset,
              child: _healthDot(health, compact: true),
            ),
          Positioned(
            left: inset,
            right: inset,
            bottom: inset,
            child: Text(
              widget.stream.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: health == false ? Colors.white54 : Colors.white,
                fontSize: titleSize,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streamThumb() {
    return widget.stream.icon.isEmpty
        ? const _StreamPlaceholder()
        : Image.network(
            widget.stream.icon,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _StreamPlaceholder(),
            loadingBuilder: (_, child, p) =>
                p == null ? child : const _StreamPlaceholder(),
          );
  }

  Widget _healthDot(bool health, {bool compact = false}) {
    final size = compact ? 8.0 : 10.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: health ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        border: Border.all(color: Colors.black54, width: 1),
      ),
    );
  }
}

class _StreamRowTile extends StatefulWidget {
  const _StreamRowTile({
    required this.stream,
    required this.ctrl,
    required this.categoryName,
    required this.onTap,
    this.listIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
  });

  final IptvStream stream;
  final IptvController ctrl;
  final String categoryName;
  final VoidCallback onTap;
  final int? listIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;

  @override
  State<_StreamRowTile> createState() => _StreamRowTileState();
}

class _StreamRowTileState extends State<_StreamRowTile> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _syncLiveProbe(hovered || _focused);
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _syncLiveProbe(focused || _hovered);
  }

  void _syncLiveProbe(bool active) {
    if (widget.stream.kind != 'live') return;
    if (active) {
      widget.ctrl.scheduleLazyCheck(widget.stream);
    } else {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
  }

  Color _surfaceColor(bool active, bool? health) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _borderColor(bool active, bool? health) {
    if (widget.stream.kind != 'live' || health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    return health
        ? const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45)
        : const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final health = widget.stream.kind == 'live'
            ? widget.ctrl.healthFor(widget.stream.streamId)
            : null;
        final active = _active(context);
        final tile = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _surfaceColor(active, health),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor(active, health)),
            ),
            child: iptvTap(
              context: context,
              onTap: widget.onTap,
              borderRadius: 12,
              scaleOnFocus: 1.0,
              listIndex: widget.listIndex,
              tvItemIndex: widget.listIndex,
              tvRowId: 'browser-streams',
              tvZone: ShellTvZone.row,
              onLeftEdge: widget.onLeftEdge,
              onRightEdge: widget.onRightEdge,
              onUpEdge: widget.onUpEdge,
              onFocusChange: _onFocus,
              onHoverChange: _onHover,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.stream.icon.isEmpty
                                ? const _StreamPlaceholder()
                                : Image.network(
                                    widget.stream.icon,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const _StreamPlaceholder(),
                                    loadingBuilder: (_, child, p) => p == null
                                        ? child
                                        : const _StreamPlaceholder(),
                                  ),
                            _StreamThumbPlayHint(active: active),
                          ],
                        ),
                      ),
                    ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.stream.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: health == false
                                      ? Colors.white54
                                      : Colors.white,
                                  fontSize: 12,
                                  height: 1.18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.categoryName.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10,
                                    height: 1.1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (widget.stream.kind == 'live')
                                _EpgNowFooter(
                                  stream: widget.stream,
                                  ctrl: widget.ctrl,
                                ),
                            ],
                          ),
                        ),
                        if (health != null)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: health
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                            ),
                          )
                        else
                          AnimatedOpacity(
                            opacity: active ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.play_circle_outline_rounded,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (widget.stream.kind != 'live') return tile;
        return _LiveHealthProbe(
          stream: widget.stream,
          ctrl: widget.ctrl,
          child: tile,
        );
      },
    );
  }
}

/// Platform-specific lazy health probe — desktop hover, TV focus, mobile visibility.
class _LiveHealthProbe extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  final Widget child;

  const _LiveHealthProbe({
    required this.stream,
    required this.ctrl,
    required this.child,
  });

  static bool isDesktopPlatform() =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Mobile touch scrolling needs visibility + scroll debounce.
  static bool usesScrollDebounce(BuildContext context) =>
      !isDesktopPlatform() &&
      resolveShellProfile(context) == ShellProfile.mobile;

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform() || isTvProfile(context)) {
      return child;
    }

    return VisibilityDetector(
      key: Key('live-${stream.streamId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.4) {
          ctrl.scheduleLazyCheck(stream);
        } else if (info.visibleFraction <= 0.05) {
          ctrl.cancelLazyCheck(stream.streamId);
        }
      },
      child: child,
    );
  }
}

/// Tiny "NOW · Title  •  HH:mm–HH:mm" strip rendered at the bottom of a live
/// `_StreamCard`. Quietly renders nothing while loading or when the panel has
/// no EPG for this channel — we never want a visible spinner per tile.
class _EpgNowFooter extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  const _EpgNowFooter({required this.stream, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: ctrl.epgFor(stream),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        final now = data.firstWhere((e) => e.isNow, orElse: () => data.first);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: now.isNow
                      ? const Color(0xFFEF4444)
                      : IptvShellStyle.accent.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  now.isNow ? 'NOW' : 'NEXT',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  now.title.isEmpty ? '—' : now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Long-press detail sheet — lists the next few programmes with start times.
class _EpgSheet extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  const _EpgSheet({required this.stream, required this.ctrl});

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stream.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: FutureBuilder<List<EpgEntry>>(
                    future: ctrl.epgFor(stream, limit: 8),
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: IptvShellStyle.accent,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final data = snap.data ?? const <EpgEntry>[];
                      if (data.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No EPG available for this channel.',
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in data)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 86,
                                    child: Text(
                                      '${_fmtTime(e.start)}–${_fmtTime(e.stop)}',
                                      style: GoogleFonts.poppins(
                                        color: e.isNow
                                            ? const Color(0xFFEF4444)
                                            : Colors.white60,
                                        fontSize: 11,
                                        fontWeight: e.isNow
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.title.isEmpty ? '—' : e.title,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (e.description.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              e.description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamPlaceholder extends StatelessWidget {
  const _StreamPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.03),
      child: const Center(
        child: Icon(Icons.tv_rounded, color: Colors.white24, size: 36),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EPISODE LIST
// ─────────────────────────────────────────────────────────────────────────────
