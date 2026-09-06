part of '../live_sports_hub_page.dart';

mixin _LiveMatchesBuild on ConsumerState<LiveSportsHubPage> {
  _LiveSportsHubPageState get _s => this as _LiveSportsHubPageState;

  bool _tvFocus(BuildContext context) =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  bool get _hasSportChips =>
      _s._sports.length > 1 && _s._tabController != null;

  int get _chipSortOrder => 1;

  int get _gridSortOrder {
    var order = 1;
    if (_hasSportChips) order++;
    return order;
  }

  static const _matchCardWidthScale = 1.15;
  static const _matchCardHeightScale = 1.32;

  /// Caption band under the 16:9 art on TV (title + optional subtitle).
  double _tvMatchCaptionBand(BuildContext context) =>
      shellScaled(context, 40).clamp(32.0, 48.0);

  /// TV: landscape continue-watching cell + caption under.
  /// Desktop/phone: continue-watching landscape tile (height clamp keeps room
  /// for overlay title/teams).
  double _matchCardWidth(BuildContext context) {
    if (ShellScope.metricsOf(context).usesTvDensity) {
      return shellContinueWatchingCardWidth(context);
    }
    return shellContinueWatchingCardWidth(context) * _matchCardWidthScale;
  }

  double _matchCardHeight(BuildContext context) {
    if (ShellScope.metricsOf(context).usesTvDensity) {
      return shellContinueWatchingCardHeight(context) +
          _tvMatchCaptionBand(context);
    }
    final height =
        shellContinueWatchingCardHeight(context) * _matchCardHeightScale;
    return height.clamp(190.0, 230.0);
  }

  double _gridGap(BuildContext context) =>
      shellMovieCardRowGap(context).clamp(8.0, 12.0);

  EdgeInsets _gridPadding(BuildContext context) {
    final horizontal = shellHomeSectionHorizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, 4, horizontal, 20);
  }

  /// Column count must match the grid delegate and D-pad Left/Right math
  /// (padding + gap), or the last card in a row wraps to the next row.
  int _gridColumns(
    BuildContext context,
    BoxConstraints constraints,
    double cardWidth,
  ) {
    final gap = _gridGap(context);
    final inner = (constraints.maxWidth - _gridPadding(context).horizontal)
        .clamp(0.0, double.infinity);
    if (cardWidth <= 0) return 1;
    return ((inner + gap) / (cardWidth + gap)).floor().clamp(1, 8);
  }

  /// Trap horizontal D-pad at the visual row ends - no wrap to the next/prev row.
  ({VoidCallback? onLeftEdge, VoidCallback? onRightEdge}) _gridRowEdgeCallbacks({
    required int index,
    required int crossCount,
    required int itemCount,
  }) {
    if (crossCount <= 0) {
      return (onLeftEdge: null, onRightEdge: null);
    }
    final atLeft = index % crossCount == 0;
    final atRight =
        (index % crossCount) == crossCount - 1 || index >= itemCount - 1;
    return (
      onLeftEdge: atLeft ? ShellTvFocusCoordinator.focusActiveNavTab : null,
      // Empty callback claims the key so focus does not wrap to the next row.
      onRightEdge: atRight ? () {} : null,
    );
  }


  ({IconData icon, Color accent}) _sportCircleMeta(String label) {
    final key = label.toLowerCase().trim();
    if (key == 'all') {
      return (
        icon: Icons.grid_view_rounded,
        accent: ForjaShellColors.sectionAccent,
      );
    }
    if (key.contains('american football') ||
        key.contains('nfl') ||
        key.contains('ncaaf')) {
      return (
        icon: Icons.sports_football_rounded,
        accent: const Color(0xFF22C55E),
      );
    }
    if (key.contains('basketball') ||
        key.contains('nba') ||
        key.contains('ncaab') ||
        key.contains('wnba')) {
      return (
        icon: Icons.sports_basketball_rounded,
        accent: const Color(0xFFF97316),
      );
    }
    // Soccer before generic "football" — IPTV labels often say "Football".
    if (key.contains('soccer') ||
        key.contains('football') ||
        key.contains('fifa') ||
        key.contains('premier league') ||
        key.contains('la liga') ||
        key.contains('serie a') ||
        key.contains('bundesliga')) {
      return (
        icon: Icons.sports_soccer_rounded,
        accent: const Color(0xFF10B981),
      );
    }
    if (key.contains('baseball') || key.contains('mlb')) {
      return (
        icon: Icons.sports_baseball_rounded,
        accent: const Color(0xFFEF4444),
      );
    }
    if (key.contains('hockey') ||
        key.contains('nhl') ||
        key.contains('ice hockey')) {
      return (
        icon: Icons.sports_hockey_rounded,
        accent: const Color(0xFF38BDF8),
      );
    }
    if (key.contains('tennis') || key.contains('tenis') || key.contains('atp')) {
      return (
        icon: Icons.sports_tennis_rounded,
        accent: const Color(0xFFA3E635),
      );
    }
    if (key.contains('cricket') ||
        key.contains('krykiet') ||
        key.contains('ipl')) {
      return (
        icon: Icons.sports_cricket_rounded,
        accent: const Color(0xFF84CC16),
      );
    }
    if (key.contains('rugby') || key.contains('nrl') || key.contains('afl')) {
      return (
        icon: Icons.sports_rugby_rounded,
        accent: const Color(0xFF16A34A),
      );
    }
    if (key.contains('golf')) {
      return (
        icon: Icons.sports_golf_rounded,
        accent: const Color(0xFF65A30D),
      );
    }
    if (key.contains('volleyball') || key.contains('volley')) {
      return (
        icon: Icons.sports_volleyball_rounded,
        accent: const Color(0xFF06B6D4),
      );
    }
    if (key.contains('handball')) {
      return (
        icon: Icons.sports_handball_rounded,
        accent: const Color(0xFF0EA5E9),
      );
    }
    if (key.contains('wrestling') ||
        key.contains('wwe') ||
        key.contains('ufc') ||
        key.contains('mma') ||
        key.contains('boxing') ||
        key.contains('fight') ||
        key.contains('combat') ||
        key.contains('martial')) {
      return (icon: Icons.sports_mma_rounded, accent: const Color(0xFFF43F5E));
    }
    if (key.contains('motor') ||
        key.contains('racing') ||
        key.contains('f1') ||
        key.contains('nascar') ||
        key.contains('formula')) {
      return (
        icon: Icons.sports_motorsports_rounded,
        accent: const Color(0xFFEAB308),
      );
    }
    if (key.contains('dart')) {
      return (icon: Icons.gps_fixed_rounded, accent: const Color(0xFFEC4899));
    }
    if (key.contains('snooker') ||
        key.contains('billiard') ||
        key == 'pool' ||
        key.contains('8-ball') ||
        key.contains('8 ball')) {
      return (icon: Icons.circle_rounded, accent: const Color(0xFF14B8A6));
    }
    if (key.contains('swim') || key.contains('aquatic')) {
      return (icon: Icons.pool_rounded, accent: const Color(0xFF3B82F6));
    }
    if (key.contains('ski') || key.contains('snow') || key.contains('winter')) {
      return (
        icon: Icons.downhill_skiing_rounded,
        accent: const Color(0xFF94A3B8),
      );
    }
    if (key.contains('esport') || key.contains('e-sport') || key.contains('gaming')) {
      return (
        icon: Icons.sports_esports_rounded,
        accent: const Color(0xFFA855F7),
      );
    }
    if (key.contains('24/7') ||
        key.contains('24-7') ||
        key.contains('live tv') ||
        key.contains('livetv') ||
        key.contains('tv show') ||
        key.contains('big brother') ||
        key.contains('reality') ||
        key.contains('stream')) {
      return (icon: Icons.live_tv_rounded, accent: const Color(0xFF8B5CF6));
    }
    if (key.contains('misc') || key.contains('other') || key.contains('general')) {
      return (icon: Icons.sports_rounded, accent: const Color(0xFF64748B));
    }
    return (icon: Icons.sports_rounded, accent: ForjaShellColors.sectionAccent);
  }

  String _sportLabelAt(int index) =>
      index == 0 ? 'All' : _s._sports[index - 1].name;

  Widget _buildSportCircleItem({
    required ShellMoodCircleLayout layout,
    required int index,
    required int itemCount,
    required bool tvFocus,
    TvChipEdges? edges,
  }) {
    final label = _sportLabelAt(index);
    final meta = _sportCircleMeta(label);
    final selected = _s._tabController!.index == index;

    return ShellMoodCircleItem(
      layout: layout,
      label: label,
      icon: meta.icon,
      accent: meta.accent,
      selected: selected,
      listIndex: index,
      tvTabId: _LiveSportsHubPageState._tabId,
      tvRowId: _LiveSportsHubPageState._chipRowId,
      onTap: () {
        if (index != _s._tabController!.index) {
          _s._tabController!.animateTo(index);
        } else if (tvFocus) {
          edges?.onSelectAlreadySelected();
        }
      },
      onLeftEdge: edges?.onLeft,
      onRightEdge: edges?.onRight,
      onDownEdge: edges?.onDown,
      // Always target live-top-bar — do not use edges.onUp / moveVerticalInTab.
      // Picker sheets also register at sortOrder 0 on this tab; a generic ↑ can
      // land on a dead sheet row and swallow the key (Stremio: stuck on sports).
      onUpEdge: _s._focusFromSportChipsUp,
    );
  }

  Widget _buildCenteredSportCircles({
    required ShellMoodCircleLayout layout,
    required int itemCount,
    required bool scaleToFit,
    required bool tvFocus,
    AlignmentGeometry alignment = Alignment.center,
    TvChipEdges Function(int index)? edgesFor,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          if (i > 0) SizedBox(width: layout.horizontalGap),
          _buildSportCircleItem(
            layout: layout,
            index: i,
            itemCount: itemCount,
            tvFocus: tvFocus,
            edges: edgesFor?.call(i),
          ),
        ],
      ],
    );

    return SizedBox(
      height: layout.rowHeight,
      width: double.infinity,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: scaleToFit
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: row,
              )
            : Align(alignment: alignment, child: row),
      ),
    );
  }
  List<_LiveMatchGridEntry> get _allGridEntries {
    final rev = _s._liveMatchesGridCacheRevision;
    final cached = _s._cachedLiveMatchesGridEntries;
    if (cached != null && _s._liveMatchesGridEntriesCachedAtRevision == rev) {
      return cached;
    }
    final sources =
        (this as _LiveMatchesForjaLive)._catalogFilteredGridSources();
    final merged = _mergeIframeAndScheduleEntries(
      iframeCatalog: sources.iframeCatalog,
      streamed: sources.streamed,
      mergeMatching: _s._mergeMatchingEvents,
    );
    _s._cachedLiveMatchesGridEntries = merged;
    _s._liveMatchesGridEntriesCachedAtRevision = rev;
    return merged;
  }

  List<_LiveMatchGridEntry> get _visibleGridEntries {
    final q = _s._matchListQuery.trim().toLowerCase();
    final all = _allGridEntries;
    if (q.isEmpty) return all;
    return [
      for (final e in all)
        if (_gridEntryMatchesQuery(e, q)) e,
    ];
  }

  bool _gridEntryMatchesQuery(_LiveMatchGridEntry entry, String q) {
    final hay = switch (entry) {
      _LiveMatchGridEntryIframeCatalog(:final stream) =>
        '${stream.name} ${stream.categoryName}',
      _LiveMatchGridEntryStreamed(:final match) =>
        '${_denseMatchTitle(match)} ${match.categoryLabel} ${match.title}',
      _LiveMatchGridEntryMerged(:final iframeCatalog, :final streamed) =>
        '${_denseMatchTitle(streamed)} ${streamed.categoryLabel} '
        '${iframeCatalog.name} ${iframeCatalog.categoryName}',
    }.toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final tabVisible =
        (this as ShellTabRefresh<LiveSportsHubPage>).shellTabVisible;
    final fetchActive = tabVisible && _s._browseHydrated;
    if (fetchActive) {
      ref.listen(liveMatchesPrimaryLoadProvider, (_, next) {
        if (!mounted || !tabVisible) return;
        next.when(
          loading: () {
            // Catalog schedule uses lazy Forja Live kick — primary provider stays idle.
          },
          error: (e, _) {
            setState(() {
              _s._loading = false;
              _s._error = e.toString();
            });
            (this as _LiveMatchesData)
                ._scheduleRestoreRefreshFocus(clearWhenSettled: true);
          },
          data: (this as _LiveMatchesData)._applyPrimaryLoad,
        );
      });
      ref.watch(liveMatchesPrimaryLoadProvider);
    }

    final iptvCtrl = _s._showIptvPortalTopBar
        ? ref.watch(iptvControllerProvider)
        : null;
    if (iptvCtrl != null) {
      ref.listen(iptvControllerProvider, (prev, next) {
        // Use live shellTabVisible — hide does not rebuild, so closed-over
        // tabVisible from build would stay true on the IPTV tab.
        if (!_s._showIptvPortalTopBar ||
            !mounted ||
            !(this as ShellTabRefresh<LiveSportsHubPage>).shellTabVisible) {
          return;
        }
        final key = next.activePortal?.key;
        if (key == null) return;
        if (key == _s._lastSyncedIptvPortalKey &&
            (prev == null || prev.portalPanelOpen == next.portalPanelOpen)) {
          return;
        }
        unawaited(
          (this as _LiveMatchesData)._syncMyIptvFromActivePortal(
            next,
            reload: true,
          ),
        );
      });
    }

    // Sport chips stay full-bleed; streams / portal panels only split the
    // match list (panel top aligns under the category bar).
    // Portals overlays the whole body (including streams) when open.
    final matchList = _buildBody();
    final withStreams = _buildStreamsPanelStack(context, matchList);
    final listWithPanels = iptvCtrl == null
        ? withStreams
        : _buildIptvPortalStack(context, iptvCtrl, withStreams);

    return TvFocusGraph(
      tabId: _LiveSportsHubPageState._tabId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(iptvCtrl),
          if (_hasSportChips) ...[
            _buildSportTabs(),
            const SizedBox(height: 2),
          ],
          Expanded(child: listWithPanels),
        ],
      ),
    );
  }

  Widget _buildIptvPortalStack(
    BuildContext context,
    IptvController ctrl,
    Widget content,
  ) {
    const panelWidth = 380.0;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final useSidePanel = wide || ShellTokens.isAndroidTvDevice;
    return Stack(
      children: [
        content,
        if (ctrl.portalPanelOpen && useSidePanel)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: panelWidth,
            child: IptvPortalPanel(
              ctrl: ctrl,
              width: panelWidth,
              onClose: ctrl.closePortalPanel,
            ),
          ),
        if (ctrl.portalPanelOpen && !useSidePanel)
          Positioned.fill(
            child: GestureDetector(
              onTap: ctrl.closePortalPanel,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {},
                    child: IptvPortalPanel(
                      ctrl: ctrl,
                      width: MediaQuery.sizeOf(context).width * 0.92,
                      onClose: ctrl.closePortalPanel,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStreamsPanelStack(BuildContext context, Widget content) {
    final match = _s._streamsPanelMatch;
    if (match == null) return content;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final useSideSplit = wide || ShellTokens.isAndroidTvDevice;
    final panel = KeyedSubtree(
      key: ValueKey('live-streams-${match.id}'),
      child: _LiveMatchDetailsScreen(
        host: _s,
        match: match,
        iframeCatalogAnchor: _s._streamsPanelIframeAnchor,
        asSidePanel: true,
      ),
    );
    // Desktop / TV: match list 60% + panel 40% (chips stay full-bleed above).
    if (useSideSplit) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 60, child: content),
          Expanded(
            flex: 40,
            child: Material(
              color: ForjaShellColors.surfaceElevated,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: ForjaShellColors.borderSubtle),
                  ),
                ),
                child: panel,
              ),
            ),
          ),
        ],
      );
    }
    // Phone: sheet overlay (list stays full-bleed under scrim).
    return Stack(
      children: [
        content,
        Positioned.fill(
          child: GestureDetector(
            onTap: _s.closeMatchStreamsPanel,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.92,
                    child: Material(
                      color: ForjaShellColors.surfaceElevated,
                      child: panel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader([IptvController? iptvCtrl]) {
    final tvFocus = _tvFocus(context);
    final catalogBusy = _s._topBarCatalogWorkInProgress;
    final forjaLive = this as _LiveMatchesForjaLive;
    final topBarItemCount = tvFocus
        ? (_s._showIptvPortalTopBar
            ? (_s._topBarCatalogWorkInProgress
                ? _s._topBarSearchIndex + 1
                : _s._topBarPortalIndex + 1)
            : _s._topBarSearchIndex + 1)
        : (_LiveSportsHubPageState._timelineViewEnabled
            ? _s._topBarViewIndex + 1
            : _s._topBarSearchIndex + 1);

    final Widget refreshSlot;
    if (catalogBusy) {
      refreshSlot = _LiveMatchesCatalogProgressChip(
        label: forjaLive._forjaLiveCatalogProgressLabel,
      );
    } else if (tvFocus) {
      refreshSlot = _LiveMatchesRefreshTopBarButton(
        focusNode: _s._refreshFocusNode,
        tvItemIndex: _s._topBarRefreshIndex,
        onTap: _s._onTopBarRefreshPressed,
        onDownEdge: _s._topBarDownEdge,
        onLeftEdge: () => _s._focusTopBarItem(
          _s._showTimeTopBar
              ? _s._topBarTimeIndex
              : _s._showCatalogTopBar
                  ? _s._topBarCatalogIndex
                  : _s._topBarRefreshIndex,
        ),
        onRightEdge: () => _s._focusTopBarSearch(),
      );
    } else {
      refreshSlot = IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
        onPressed: _s._load,
      );
    }

    final searchSlot = _LiveMatchesSearchTopBarControl(
      open: _s._matchSearchOpen,
      controller: _s._matchSearchCtrl,
      iconFocusNode: _s._searchIconFocusNode,
      fieldFocusNode: _s._matchSearchFocusNode,
      tvItemIndex: _s._topBarSearchIndex,
      onOpen: _s._openMatchSearch,
      onChanged: _s._onMatchSearchChanged,
      onClose: () => _s._closeMatchSearch(clearQuery: true),
      onDownEdge: _s._topBarDownEdge,
      onLeftEdge: () {
        if (catalogBusy) {
          _s._focusTopBarItem(
            _s._showTimeTopBar
                ? _s._topBarTimeIndex
                : _s._showCatalogTopBar
                    ? _s._topBarCatalogIndex
                    : _s._topBarSearchIndex,
          );
          return;
        }
        _s._focusTopBarItem(_s._topBarRefreshIndex);
      },
      onRightEdge: _s._showIptvPortalTopBar
          ? () => _s._focusTopBarItem(_s._topBarPortalFocusIndex)
          : () {},
    );

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        10,
        ShellTokens.bodyHorizontalPadding,
        8,
      ),
      child: Row(
        children: [
          if (_s._showCatalogTopBar) ...[
            _s._catalogTopBarButton(),
            if (_s._showTimeTopBar) const SizedBox(width: 8),
          ],
          if (_s._showTimeTopBar) _s._timeTopBarButton(),
          const Spacer(),
          refreshSlot,
          const SizedBox(width: 4),
          searchSlot,
          if (!_liveMatchesLeanbackOnly(context) &&
              _LiveSportsHubPageState._timelineViewEnabled) ...[
            const SizedBox(width: 4),
            _buildViewToggle(),
          ],
          if (_s._showIptvPortalTopBar && iptvCtrl != null) ...[
            const SizedBox(width: 8),
            _s._iptvPortalTopBarButton(iptvCtrl),
          ],
        ],
      ),
    );

    if (!tvFocus) return header;
    return TvCatalogRow(
      tabId: _LiveSportsHubPageState._tabId,
      rowId: _LiveSportsHubPageState._topBarRowId,
      sortOrder: 0,
      itemCount: topBarItemCount,
      child: header,
    );
  }

  Widget _buildViewToggle() {
    final isTimeline = _s._view == _LiveMatchesView.timeline;
    final icon = isTimeline
        ? Icons.grid_view_rounded
        : Icons.view_timeline_rounded;
    final tip = isTimeline ? 'Card view' : 'Timeline view';

    return IconButton(
      tooltip: tip,
      icon: Icon(icon, color: Colors.white70),
      onPressed: _s._toggleView,
    );
  }

  Widget _buildSportTabs() {
    if (!_hasSportChips) {
      return const SizedBox.shrink();
    }

    final itemCount = _s._sports.length + 1;
    final tvFocus = _tvFocus(context);
    final resultsRowId = _LiveSportsHubPageState._gridRowId;

    return Padding(
      padding: EdgeInsets.only(
        left: ShellTokens.compactChromeLeadingInset(context),
        right: ShellTokens.bodyHorizontalPadding,
        top: 2,
        bottom: 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fixed chip size — only as many as fit stay in view; rest scroll.
          final layout = tvFocus
              ? ShellMoodCircleLayout.tvScrollable
              : ShellMoodCircleLayout.desktop;
          final overflows =
              layout.contentWidth(itemCount) > constraints.maxWidth;

          Widget strip({TvChipEdges Function(int index)? edgesFor}) {
            if (!overflows) {
              return _buildCenteredSportCircles(
                layout: layout,
                itemCount: itemCount,
                scaleToFit: false,
                tvFocus: tvFocus,
                edgesFor: edgesFor,
              );
            }
            return SizedBox(
              height: layout.rowHeight,
              width: double.infinity,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: HorizontalScroller(
                  height: layout.rowHeight,
                  itemCount: itemCount,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: layout.horizontalGap),
                  itemBuilder: (context, i) => _buildSportCircleItem(
                    layout: layout,
                    index: i,
                    itemCount: itemCount,
                    tvFocus: tvFocus,
                    edges: edgesFor?.call(i),
                  ),
                ),
              ),
            );
          }

          if (tvFocus) {
            return TvChipStrip(
              tabId: _LiveSportsHubPageState._tabId,
              rowId: _LiveSportsHubPageState._chipRowId,
              sortOrder: _chipSortOrder,
              itemCount: itemCount,
              resultsRowId: resultsRowId,
              builder: (context, edgesFor) => strip(edgesFor: edgesFor),
            );
          }

          return strip();
        },
      ),
    );
  }

  Widget _buildBody() {
    if (!_s._browseHydrated) {
      return Center(
        child: CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
      );
    }
    if (_s._loading) {
      final showPartialCatalog = _s._iframeCatalogStreams.isNotEmpty ||
          _s._streamedMatches.isNotEmpty ||
          (this as _LiveMatchesForjaLive)._forjaLiveCatalogBusy;
      if (!showPartialCatalog) {
        return Center(
          child: CircularProgressIndicator(
            color: ForjaShellColors.sectionAccent,
          ),
        );
      }
    }
    if (_s._error != null) {
      return ShellErrorRetryPanel(
        message: _s._error!,
        onRetry: _s._load,
        statusIcon: Icons.error_outline,
        buttonIcon: Icons.refresh,
      );
    }
    final forjaLive = this as _LiveMatchesForjaLive;
    if (forjaLive._forjaLiveCatalogBusy &&
        _allGridEntries.isEmpty &&
        forjaLive._displayStreamedMatches.isEmpty &&
        _s._iframeCatalogStreams.isEmpty) {
      return _buildForjaLiveCatalogProgress();
    }
    return _buildAllBody();
  }

  Widget _buildAllBody() {
    final entries = _visibleGridEntries;
    if (entries.isEmpty) {
      if ((this as _LiveMatchesForjaLive)._forjaLiveCatalogBusy &&
          _allGridEntries.isEmpty) {
        return _buildForjaLiveCatalogProgress();
      }
      final q = _s._matchListQuery.trim();
      if (q.isNotEmpty && _allGridEntries.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No matches for "$q"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        );
      }
      final forjaLive = this as _LiveMatchesForjaLive;
      final emptyMsg = kLiveMatchesCatalogFiltersHidden
          ? 'Catalog schedule feeds are temporarily hidden'
          : forjaLive._showForjaLiveCatalogChrome
              ? 'No matches for this catalog, sport, or schedule window. Try another catalog, a wider time window, or Refresh.'
              : 'No Forja Live matches. Enable plugins in Settings → Forja Sports → Live Forja plugins.';
      return ShellErrorRetryPanel(
        message: emptyMsg,
        onRetry: _s._load,
        label: 'Refresh',
        statusIcon: Icons.sports_rounded,
        buttonIcon: Icons.refresh,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._clearTimelineTvRows();
        }
        if (_s.useDenseMatchList) {
          return _buildDenseMatchList(
            context: context,
            entries: entries,
            tvFocus: tvFocus,
          );
        }
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(context, constraints, cardWidth);
        final grid = GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final edges = _gridRowEdgeCallbacks(
              index: i,
              crossCount: crossCount,
              itemCount: entries.length,
            );
            return _gridEntryCard(
              entries[i],
              i,
              crossCount,
              _s._gridUpEdge(context, i, crossCount),
              onLeftEdge: edges.onLeftEdge,
              onRightEdge: edges.onRightEdge,
            );
          },
        );
        if (!tvFocus) return grid;
        return TvGrid(
          tabId: _LiveSportsHubPageState._tabId,
          rowId: _LiveSportsHubPageState._gridRowId,
          sortOrder: _gridSortOrder,
          itemCount: entries.length,
          columns: crossCount,
          onFocusUp: _s._gridFocusUp,
          child: grid,
        );
      },
    );
  }

  Widget _buildDenseMatchList({
    required BuildContext context,
    required List<_LiveMatchGridEntry> entries,
    required bool tvFocus,
  }) {
    final list = ListView.separated(
      padding: _gridPadding(context),
      itemCount: entries.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
      ),
      itemBuilder: (context, i) {
        final entry = entries[i];
        return KeyedSubtree(
          key: ValueKey(_denseMatchEntryKey(entry)),
          child: _denseMatchListTile(
            entry: entry,
            index: i,
            tvFocus: tvFocus,
          ),
        );
      },
    );
    if (!tvFocus) return list;
    return TvGrid(
      tabId: _LiveSportsHubPageState._tabId,
      rowId: _LiveSportsHubPageState._gridRowId,
      sortOrder: _gridSortOrder,
      itemCount: entries.length,
      columns: 1,
      onFocusUp: _s._gridFocusUp,
      child: list,
    );
  }

  Widget _denseMatchListTile({
    required _LiveMatchGridEntry entry,
    required int index,
    required bool tvFocus,
  }) {
    final selectedId = _s._streamsPanelMatch?.id;
    late final String title;
    late final String meta;
    late final bool live;
    late final bool playable;
    late final VoidCallback? onTap;
    var viewers = 0;

    switch (entry) {
      case _LiveMatchGridEntryIframeCatalog(:final stream):
        title = stream.name;
        meta = [
          if (stream.categoryName.trim().isNotEmpty) stream.categoryName.trim(),
          if (stream.timeLabel.trim().isNotEmpty) stream.timeLabel.trim(),
        ].join(' · ');
        live = stream.isLive;
        playable = stream.isLive;
        viewers = _s._eventStreamViewerTotals[
                _liveEventViewerKeyFromIframeCatalog(stream)] ??
            stream.viewers;
        onTap = playable ? () => _s._openIframeCatalogStream(stream) : null;
      case _LiveMatchGridEntryStreamed(:final match):
        title = _denseMatchTitle(match);
        meta = [
          if (match.categoryLabel.trim().isNotEmpty) match.categoryLabel.trim(),
          if (match.isLive)
            'Live'
          else if (match.scheduleLabel.isNotEmpty)
            match.scheduleLabel
          else if (match.timeLabel.isNotEmpty)
            match.timeLabel,
        ].join(' · ');
        live = match.isLive;
        playable =
            (this as _LiveMatchesForjaLive)._forjaLiveMatchPlayable(match);
        viewers = cardViewersForMatch(match);
        onTap = playable ? () => _s._openStreamedMatch(match) : null;
      case _LiveMatchGridEntryMerged(:final iframeCatalog, :final streamed):
        title = _denseMatchTitle(streamed);
        meta = [
          if (streamed.categoryLabel.trim().isNotEmpty)
            streamed.categoryLabel.trim(),
          if (streamed.isLive || iframeCatalog.isLive)
            'Live'
          else if (streamed.scheduleLabel.isNotEmpty)
            streamed.scheduleLabel,
        ].join(' · ');
        live = streamed.isLive || iframeCatalog.isLive;
        playable = live;
        viewers = _s._eventStreamViewerTotals[_liveEventViewerKey(streamed)] ??
            (iframeCatalog.viewers +
                (_s._mergeMatchingEvents
                    ? _catalogViewersForEvent(streamed, _s._streamedMatches)
                    : streamed.viewers));
        onTap = playable
            ? () => _s._openMergedMatch(iframeCatalog, streamed)
            : null;
    }

    final selected = selectedId != null &&
        ((entry is _LiveMatchGridEntryStreamed &&
                entry.match.id == selectedId) ||
            (entry is _LiveMatchGridEntryMerged &&
                entry.streamed.id == selectedId));

    return _DenseLiveMatchListTile(
      title: title,
      meta: meta,
      live: live,
      playable: playable,
      viewers: viewers,
      selected: selected,
      index: index,
      tvFocus: tvFocus,
      onTap: onTap,
      onUpEdge: tvFocus ? _s._gridUpEdge(context, index, 1) : null,
      onRightEdge: tvFocus && _s._streamsPanelMatch != null
          ? () => ShellTvFocusCoordinator.focusRowItem(
                _LiveSportsHubPageState._tabId,
                _LiveSportsHubPageState._streamsTabsRowId,
                0,
              )
          : null,
    );
  }

  String _denseMatchTitle(_StreamedMatch match) {
    final home = (match.homeTeam ?? '').trim();
    final away = (match.awayTeam ?? '').trim();
    if (home.isNotEmpty && away.isNotEmpty) return '$home vs $away';
    return match.title;
  }

  /// Shared backdrop card for a unified grid entry - reused by the card grid
  /// and the timeline view so both render identical posters/badges.
  Widget _gridEntryCard(
    _LiveMatchGridEntry entry,
    int i,
    int crossCount,
    VoidCallback? upEdge, {
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    bool forceActive = false,
    ValueChanged<bool>? onHoverChanged,
    String tvRowId = 'grid',
    ShellTvZone tvZone = ShellTvZone.grid,
  }) {
    return switch (entry) {
      _LiveMatchGridEntryIframeCatalog(:final stream) => _IframeCatalogMatchCard(
        stream: stream,
        viewersOverride: _s._eventStreamViewerTotals[
                _liveEventViewerKeyFromIframeCatalog(stream)] ??
            stream.viewers,
        gridIndex: i,
        gridColumns: crossCount,
        onUpEdge: upEdge,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        forceActive: forceActive,
        onHoverChanged: onHoverChanged,
        tvRowId: tvRowId,
        tvZone: tvZone,
        onTap: () => _s._openIframeCatalogStream(stream),
      ),
      _LiveMatchGridEntryStreamed(:final match) => _StreamedMatchCard(
        match: match,
        viewersOverride: cardViewersForMatch(match),
        gridIndex: i,
        gridColumns: crossCount,
        onUpEdge: upEdge,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        forceActive: forceActive,
        onHoverChanged: onHoverChanged,
        tvRowId: tvRowId,
        tvZone: tvZone,
        playableOverride:
            (this as _LiveMatchesForjaLive)._forjaLiveMatchPlayable(match),
        onTap: () => _s._openStreamedMatch(match),
      ),
      _LiveMatchGridEntryMerged(:final iframeCatalog, :final streamed) =>
        _IframeCatalogMatchCard(
          stream: iframeCatalog,
          viewersOverride: _s._eventStreamViewerTotals[
                  _liveEventViewerKey(streamed)] ??
              (iframeCatalog.viewers +
                  (_s._mergeMatchingEvents
                      ? _catalogViewersForEvent(streamed, _s._streamedMatches)
                      : streamed.viewers)),
          gridIndex: i,
          gridColumns: crossCount,
          onUpEdge: upEdge,
          onLeftEdge: onLeftEdge,
          onRightEdge: onRightEdge,
          forceActive: forceActive,
          onHoverChanged: onHoverChanged,
          tvRowId: tvRowId,
          tvZone: tvZone,
          playableOverride: iframeCatalog.isLive || streamed.isLive,
          onTap: () => _s._openMergedMatch(iframeCatalog, streamed),
        ),
    };
  }

  /// PPV-style card badge: resolved stream total when known, else catalog sum.
  int cardViewersForMatch(_StreamedMatch match) {
    final cached = _s._eventStreamViewerTotals[_liveEventViewerKey(match)];
    if (cached != null && cached > 0) return cached;
    final inline = match.inlineStreams.fold<int>(
      0,
      (n, s) => n + (s.viewers > 0 ? s.viewers : 0),
    );
    if (inline > 0) return inline;
    if (!_s._mergeMatchingEvents) {
      return match.viewers;
    }
    final catalog = _catalogViewersForEvent(match, _s._streamedMatches);
    return catalog > 0 ? catalog : match.viewers;
  }

  String _denseMatchEntryKey(_LiveMatchGridEntry entry) {
    return switch (entry) {
      _LiveMatchGridEntryIframeCatalog(:final stream) => 'if:${stream.id}',
      _LiveMatchGridEntryStreamed(:final match) => 'st:${match.id}',
      _LiveMatchGridEntryMerged(:final iframeCatalog, :final streamed) =>
        'mg:${iframeCatalog.id}:${streamed.id}',
    };
  }

  Widget _buildForjaLiveCatalogProgress() {
    final label =
        (this as _LiveMatchesForjaLive)._forjaLiveCatalogProgressLabel;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

}

/// Dense match row — gray hover/focus fill; green selected chrome (fill + rail
/// + title/chevron) while the streams panel is open for that match.
class _DenseLiveMatchListTile extends StatefulWidget {
  const _DenseLiveMatchListTile({
    required this.title,
    required this.meta,
    required this.live,
    required this.playable,
    required this.viewers,
    required this.selected,
    required this.index,
    required this.tvFocus,
    required this.onTap,
    this.onUpEdge,
    this.onRightEdge,
  });

  final String title;
  final String meta;
  final bool live;
  final bool playable;
  final int viewers;
  final bool selected;
  final int index;
  final bool tvFocus;
  final VoidCallback? onTap;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_DenseLiveMatchListTile> createState() =>
      _DenseLiveMatchListTileState();
}

class _DenseLiveMatchListTileState extends State<_DenseLiveMatchListTile> {
  bool _focused = false;
  bool _hovered = false;

  bool get _chrome => _focused || _hovered;

  Color get _fill {
    if (widget.selected) {
      return ForjaShellColors.brandGreen.withValues(alpha: 0.18);
    }
    if (_chrome) return ForjaShellColors.inkHover;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = !widget.playable
        ? Colors.white54
        : widget.selected
            ? ForjaShellColors.brandGreen
            : ForjaShellColors.textPrimary;
    final titleWeight =
        widget.selected || _chrome ? FontWeight.w700 : FontWeight.w600;
    final accent = widget.selected
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.iconMuted;
    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: _fill,
        border: Border(
          left: BorderSide(
            color: widget.selected
                ? ForjaShellColors.brandGreen
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (widget.live)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: titleWeight,
                    ),
                  ),
                  if (widget.meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.viewers > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${widget.viewers}',
                  style: TextStyle(
                    color: widget.selected
                        ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                        : ForjaShellColors.textSecondary
                            .withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            if (widget.playable)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      showFocusBorder: false,
      showFocusRail: false,
      suppressInkHover: true,
      listIndex: widget.index,
      gridIndex: widget.tvFocus ? widget.index : null,
      gridColumns: widget.tvFocus ? 1 : null,
      tvTabId: widget.tvFocus ? _LiveSportsHubPageState._tabId : null,
      tvRowId: widget.tvFocus ? _LiveSportsHubPageState._gridRowId : null,
      tvZone: widget.tvFocus ? ShellTvZone.grid : null,
      tvItemIndex: widget.tvFocus ? widget.index : null,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onUpEdge: widget.onUpEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: row,
    );
  }
}
