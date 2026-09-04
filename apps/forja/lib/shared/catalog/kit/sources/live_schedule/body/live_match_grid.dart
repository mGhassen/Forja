part of '../live_sports_hub_page.dart';

mixin _LiveMatchesBuild on ConsumerState<LiveSportsHubPage> {
  LiveSportsHubPageState get _s => this as LiveSportsHubPageState;

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
      tvTabId: LiveSportsHubPageState._tabId,
      tvRowId: LiveSportsHubPageState._chipRowId,
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
    );
    _s._cachedLiveMatchesGridEntries = merged;
    _s._liveMatchesGridEntriesCachedAtRevision = rev;
    return merged;
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
      tabId: LiveSportsHubPageState._tabId,
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
        : (LiveSportsHubPageState._timelineViewEnabled
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
                  : _s._showCatalogTopBar
                      ? _s._topBarCatalogIndex
                      : _s._topBarRefreshIndex,
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
              LiveSportsHubPageState._timelineViewEnabled) ...[
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
      tabId: LiveSportsHubPageState._tabId,
      rowId: LiveSportsHubPageState._topBarRowId,
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
    final resultsRowId = LiveSportsHubPageState._gridRowId;

    return Padding(
      padding: EdgeInsets.only(
        left: ShellTokens.compactChromeLeadingInset(context),
        right: ShellTokens.bodyHorizontalPadding,
        top: 2,
        bottom: 10,
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
              tabId: LiveSportsHubPageState._tabId,
              rowId: LiveSportsHubPageState._chipRowId,
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
    final entries = _allGridEntries;
    if (entries.isEmpty) {
      if ((this as _LiveMatchesForjaLive)._forjaLiveCatalogBusy) {
        return _buildForjaLiveCatalogProgress();
      }
      final forjaLive = this as _LiveMatchesForjaLive;
      final emptyMsg = kLiveMatchesCatalogFiltersHidden
          ? 'Catalog schedule feeds are temporarily hidden'
          : forjaLive._showForjaLiveCatalogChrome
              ? 'No matches for this catalog, sport, or schedule window — try another catalog, a wider time window, or Refresh'
              : 'No Forja Live matches — enable plugins in Settings → Forja Sports → Live Forja plugins';
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
          tabId: LiveSportsHubPageState._tabId,
          rowId: LiveSportsHubPageState._gridRowId,
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

}
