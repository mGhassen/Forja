part of '../live_sports_hub_page.dart';

mixin _LiveMatchesBuild on ConsumerState<LiveSportsHubPage> {
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

    return TvFocusGraph(
      tabId: _LiveMatchesScreenState._tabId,
      child: content,
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
    // Leanback TV is cards-only (timeline D-pad is not supported).
    if (_LiveMatchesScreenState._timelineViewEnabled &&
        !_liveMatchesLeanbackOnly(context) &&
        _s._view == _LiveMatchesView.timeline) {
      return _s._buildTimelineBody();
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
  int _cardViewersForMatch(_StreamedMatch match) {
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
