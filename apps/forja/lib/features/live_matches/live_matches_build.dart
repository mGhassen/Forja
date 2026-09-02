part of 'live_matches_screen.dart';

mixin _LiveMatchesBuild on ConsumerState<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

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
    final key = label.toLowerCase();
    if (key == 'all') {
      return (
        icon: Icons.grid_view_rounded,
        accent: ForjaShellColors.sectionAccent,
      );
    }
    if (key.contains('american football') || key.contains('nfl')) {
      return (
        icon: Icons.sports_football_rounded,
        accent: const Color(0xFF22C55E),
      );
    }
    if (key.contains('basketball') || key.contains('nba')) {
      return (
        icon: Icons.sports_basketball_rounded,
        accent: const Color(0xFFF97316),
      );
    }
    if (key.contains('soccer') || key.contains('football')) {
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
    if (key.contains('hockey') || key.contains('nhl')) {
      return (
        icon: Icons.sports_hockey_rounded,
        accent: const Color(0xFF38BDF8),
      );
    }
    if (key.contains('tennis')) {
      return (
        icon: Icons.sports_tennis_rounded,
        accent: const Color(0xFFA3E635),
      );
    }
    if (key.contains('cricket')) {
      return (
        icon: Icons.sports_cricket_rounded,
        accent: const Color(0xFF84CC16),
      );
    }
    if (key.contains('mma') ||
        key.contains('boxing') ||
        key.contains('fight')) {
      return (icon: Icons.sports_mma_rounded, accent: const Color(0xFFF43F5E));
    }
    if (key.contains('motor') || key.contains('racing') || key.contains('f1')) {
      return (
        icon: Icons.sports_motorsports_rounded,
        accent: const Color(0xFFEAB308),
      );
    }
    if (key.contains('24/7') ||
        key.contains('24-7') ||
        key.contains('stream')) {
      return (icon: Icons.live_tv_rounded, accent: const Color(0xFF8B5CF6));
    }
    if (key.contains('misc')) {
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
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._chipRowId,
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
    final merged = _mergePpvAndStreamedEntries(
      ppv: sources.ppv,
      streamed: sources.streamed,
    );
    _s._cachedLiveMatchesGridEntries = merged;
    _s._liveMatchesGridEntriesCachedAtRevision = rev;
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final tabVisible =
        (this as ShellTabRefresh<LiveMatchesScreen>).shellTabVisible;
    final fetchActive = tabVisible && _s._serverHydrated;
    if (fetchActive) {
      ref.listen(liveMatchesPrimaryLoadProvider(_s._server), (_, next) {
        if (!mounted || !tabVisible) return;
        next.when(
          loading: () {
            if (_s._server == _LiveMatchesServer.forjaLive ||
                _s._server == _LiveMatchesServer.iptvSports ||
                _s._server == _LiveMatchesServer.all) {
              return;
            }
            if (!_s._loading) setState(() => _s._loading = true);
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
      ref.watch(liveMatchesPrimaryLoadProvider(_s._server));
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
            !(this as ShellTabRefresh<LiveMatchesScreen>).shellTabVisible) {
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

    // Content below header (sport tabs + grid). Portal panel stacks on top of
    // this so it starts under the portal button and covers categories.
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasSportChips) ...[
          _buildSportTabs(),
          const SizedBox(height: 2),
        ],
        Expanded(child: _buildBody()),
      ],
    );
    final belowHeader = iptvCtrl == null
        ? content
        : _buildIptvPortalStack(context, iptvCtrl, content);

    return TvFocusGraph(
      tabId: _LiveMatchesScreenState._tabId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(iptvCtrl),
          Expanded(child: belowHeader),
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

  Widget _buildHeader([IptvController? iptvCtrl]) {
    final tvFocus = _tvFocus(context);
    final topBarItemCount = tvFocus
        ? (_s._showIptvPortalTopBar
            ? _s._topBarPortalIndex + 1
            : _s._topBarRefreshIndex + 1)
        : (_LiveMatchesScreenState._timelineViewEnabled
            ? _s._topBarViewIndex + 1
            : _s._topBarRefreshIndex + 1);

    final refresh = tvFocus
        ? _LiveMatchesRefreshTopBarButton(
            focusNode: _s._refreshFocusNode,
            tvItemIndex: _s._topBarRefreshIndex,
            onTap: _s._onTopBarRefreshPressed,
            onDownEdge: _s._topBarDownEdge,
            onLeftEdge: () => _s._focusTopBarItem(
              _s._showTimeTopBar
                  ? _s._topBarTimeIndex
                  : _s._topBarCatalogIndex,
            ),
            onRightEdge: _s._showIptvPortalTopBar
                ? () => _s._focusTopBarItem(_s._topBarPortalIndex)
                : () {},
          )
        : IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _s._load,
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
          refresh,
          if (!_liveMatchesLeanbackOnly(context) &&
              _LiveMatchesScreenState._timelineViewEnabled) ...[
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
      tabId: _LiveMatchesScreenState._tabId,
      rowId: _LiveMatchesScreenState._topBarRowId,
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
    final resultsRowId = _LiveMatchesScreenState._gridRowId;

    return Padding(
      padding: EdgeInsets.only(
        left: ShellTokens.compactChromeLeadingInset(context),
        right: ShellTokens.bodyHorizontalPadding,
        top: 2,
        bottom: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = ShellMoodCircleLayout.resolve(
            context,
            itemCount: itemCount,
            maxWidth: constraints.maxWidth,
          );

          if (tvFocus) {
            return TvChipStrip(
              tabId: _LiveMatchesScreenState._tabId,
              rowId: _LiveMatchesScreenState._chipRowId,
              sortOrder: _chipSortOrder,
              itemCount: itemCount,
              resultsRowId: resultsRowId,
              builder: (context, edgesFor) => _buildCenteredSportCircles(
                layout: layout,
                itemCount: itemCount,
                scaleToFit: true,
                tvFocus: tvFocus,
                edgesFor: edgesFor,
              ),
            );
          }

          if (layout.contentWidth(itemCount) <= constraints.maxWidth) {
            return _buildCenteredSportCircles(
              layout: layout,
              itemCount: itemCount,
              scaleToFit: false,
              tvFocus: tvFocus,
            );
          }

          // Overflow: scale to fit and keep centered (same as TV / Anime vibes).
          return _buildCenteredSportCircles(
            layout: layout,
            itemCount: itemCount,
            scaleToFit: true,
            tvFocus: tvFocus,
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (!_s._serverHydrated) {
      return Center(
        child: CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
      );
    }
    if (_s._loading) {
      final showPartialCatalog = switch (_s._server) {
        _LiveMatchesServer.all =>
            _s._damiTvStreams.isNotEmpty ||
            _s._streamedMatches.isNotEmpty ||
            (this as _LiveMatchesForjaLive)._forjaLiveCatalogBusy,
        _ => false,
      };
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
        _s._damiTvStreams.isEmpty) {
      return _buildForjaLiveCatalogProgress();
    }
    // Leanback TV is cards-only (timeline D-pad is not supported).
    if (_LiveMatchesScreenState._timelineViewEnabled &&
        !_liveMatchesLeanbackOnly(context) &&
        _s._view == _LiveMatchesView.timeline) {
      return _s._buildTimelineBody();
    }
    if ((this as _LiveMatchesForjaLive)._showForjaLiveCatalogChrome ||
        _s._server == _LiveMatchesServer.forjaLive) {
      return _buildAllBody();
    }
    if (_s._server == _LiveMatchesServer.ppv) return _buildDamiTvBody();
    if (_s._server == _LiveMatchesServer.streamed ||
        _s._server == _LiveMatchesServer.mutStreams ||
        _s._server == _LiveMatchesServer.forjaLive ||
        _s._server == _LiveMatchesServer.stremio) {
      return _buildStreamedBody();
    }

    return const SizedBox.shrink();
  }

  Widget _buildAllBody() {
    final entries = _allGridEntries;
    if (entries.isEmpty) {
      if ((this as _LiveMatchesForjaLive)._forjaLiveCatalogBusy) {
        return _buildForjaLiveCatalogProgress();
      }
      return ShellErrorRetryPanel(
        message: 'No streams available',
        onRetry: _s._load,
        label: 'Refresh',
        statusIcon: Icons.sports_rounded,
        buttonIcon: Icons.refresh,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(context, constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._clearTimelineTvRows();
        }
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
          tabId: _LiveMatchesScreenState._tabId,
          rowId: _LiveMatchesScreenState._gridRowId,
          sortOrder: _gridSortOrder,
          itemCount: entries.length,
          columns: crossCount,
          onFocusUp: _s._gridFocusUp,
          child: grid,
        );
      },
    );
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
      _LiveMatchGridEntryPpv(:final stream) => _DamiTvMatchCard(
        stream: stream,
        viewersOverride: _s._eventStreamViewerTotals[
                _liveEventViewerKeyFromPpv(stream)] ??
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
        onTap: () => _s._openDamiTvStream(stream),
      ),
      _LiveMatchGridEntryStreamed(:final match) => _StreamedMatchCard(
        match: match,
        viewersOverride: _cardViewersForMatch(match),
        gridIndex: i,
        gridColumns: crossCount,
        onUpEdge: upEdge,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        forceActive: forceActive,
        onHoverChanged: onHoverChanged,
        tvRowId: tvRowId,
        tvZone: tvZone,
        onTap: () => _s._openStreamedMatch(match),
      ),
      _LiveMatchGridEntryMerged(:final ppv, :final streamed) =>
        _DamiTvMatchCard(
          stream: ppv,
          viewersOverride: _s._eventStreamViewerTotals[
                  _liveEventViewerKey(streamed)] ??
              (ppv.viewers +
                  _catalogViewersForEvent(streamed, _s._streamedMatches)),
          gridIndex: i,
          gridColumns: crossCount,
          onUpEdge: upEdge,
          onLeftEdge: onLeftEdge,
          onRightEdge: onRightEdge,
          forceActive: forceActive,
          onHoverChanged: onHoverChanged,
          tvRowId: tvRowId,
          tvZone: tvZone,
          playableOverride: ppv.isLive || streamed.isLive,
          onTap: () => _s._openMergedMatch(ppv, streamed),
        ),
    };
  }

  /// PPV-style card badge: resolved stream total when known, else catalog sum.
  int _cardViewersForMatch(_StreamedMatch match) {
    final cached = _s._eventStreamViewerTotals[_liveEventViewerKey(match)];
    if (cached != null && cached > 0) return cached;
    final catalog = _catalogViewersForEvent(match, _s._streamedMatches);
    return catalog > 0 ? catalog : match.viewers;
  }

  Widget _buildForjaLiveCatalogProgress() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
          const SizedBox(height: 12),
          Text(
            'Loading live catalogs…',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamedBody() {
    final matches = _s._displayStreamedMatches;
    if (matches.isEmpty) {
      if ((this as _LiveMatchesForjaLive)._forjaLiveCatalogInitialBusy) {
        return _buildForjaLiveCatalogProgress();
      }
      final forjaLive = this as _LiveMatchesForjaLive;
      final emptyMsg = switch (_s._server) {
        _LiveMatchesServer.stremio =>
          'No live Stremio addons — install one in Settings → Sources and enable Live Matches',
        _LiveMatchesServer.iptvSports => forjaLive._showForjaLiveCatalogChrome
            ? 'No matches for this catalog, sport, or schedule window — try Catalog → All, a wider time window, or Refresh'
            : 'No Forja Sports matches — enable catalogs in Settings → Forja Sports → Catalog',
        _LiveMatchesServer.forjaLive => forjaLive._showForjaLiveCatalogChrome
            ? 'No matches for this catalog, sport, or schedule window — try Catalog → All, a wider time window, or Refresh'
            : 'No Forja Live matches — enable plugins in Settings → Forja Sports → Live Forja plugins',
        _ => 'No streams available',
      };
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
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(context, constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._clearTimelineTvRows();
        }
        final grid = GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: matches.length,
          itemBuilder: (context, i) {
            final edges = _gridRowEdgeCallbacks(
              index: i,
              crossCount: crossCount,
              itemCount: matches.length,
            );
            return _StreamedMatchCard(
              match: matches[i],
              viewersOverride: _cardViewersForMatch(matches[i]),
              gridIndex: i,
              gridColumns: crossCount,
              onUpEdge: _s._gridUpEdge(context, i, crossCount),
              onLeftEdge: edges.onLeftEdge,
              onRightEdge: edges.onRightEdge,
              playableOverride: _s._server == _LiveMatchesServer.forjaLive
                  ? (this as _LiveMatchesForjaLive)._forjaLiveMatchPlayable(
                      matches[i],
                    )
                  : null,
              onTap: () => _s._openStreamedMatch(matches[i]),
            );
          },
        );
        if (!tvFocus) return grid;
        return TvGrid(
          tabId: _LiveMatchesScreenState._tabId,
          rowId: _LiveMatchesScreenState._gridRowId,
          sortOrder: _gridSortOrder,
          itemCount: matches.length,
          columns: crossCount,
          onFocusUp: _s._gridFocusUp,
          child: grid,
        );
      },
    );
  }

  Widget _buildDamiTvBody() {
    final streams = _s._filteredDamiTv;
    if (streams.isEmpty) {
      return ShellErrorRetryPanel(
        message: 'No streams available',
        onRetry: _s._load,
        label: 'Refresh',
        statusIcon: Icons.sports_rounded,
        buttonIcon: Icons.refresh,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(context, constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._clearTimelineTvRows();
        }
        final grid = GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: streams.length,
          itemBuilder: (context, i) {
            final edges = _gridRowEdgeCallbacks(
              index: i,
              crossCount: crossCount,
              itemCount: streams.length,
            );
            return _DamiTvMatchCard(
              stream: streams[i],
              viewersOverride: _s._eventStreamViewerTotals[
                      _liveEventViewerKeyFromPpv(streams[i])] ??
                  streams[i].viewers,
              gridIndex: i,
              gridColumns: crossCount,
              onUpEdge: _s._gridUpEdge(context, i, crossCount),
              onLeftEdge: edges.onLeftEdge,
              onRightEdge: edges.onRightEdge,
              onTap: () => _s._openDamiTvStream(streams[i]),
            );
          },
        );
        if (!tvFocus) return grid;
        return TvGrid(
          tabId: _LiveMatchesScreenState._tabId,
          rowId: _LiveMatchesScreenState._gridRowId,
          sortOrder: _gridSortOrder,
          itemCount: streams.length,
          columns: crossCount,
          onFocusUp: _s._gridFocusUp,
          child: grid,
        );
      },
    );
  }

}
