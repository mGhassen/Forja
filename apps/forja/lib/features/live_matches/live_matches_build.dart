part of 'live_matches_screen.dart';

mixin _LiveMatchesBuild on State<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  bool _tvFocus(BuildContext context) =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  bool get _hasSportChips => _s._tabController != null && _s._sports.isNotEmpty;

  int get _chipSortOrder => 1;

  int get _gridSortOrder => _hasSportChips ? 2 : 1;

  static const _matchCardWidthScale = 1.15;
  static const _matchCardHeightScale = 1.32;

  double _matchCardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context) * _matchCardWidthScale;

  double _matchCardHeight(BuildContext context) {
    final height =
        shellContinueWatchingCardHeight(context) * _matchCardHeightScale;
    return height.clamp(190.0, 230.0);
  }

  double _channelCardWidth(BuildContext context) =>
      (_matchCardWidth(context) * 0.9).clamp(210.0, 260.0);

  double _channelCardHeight(BuildContext context) =>
      (_matchCardHeight(context) * 0.88).clamp(130.0, 150.0);

  double _gridGap(BuildContext context) =>
      shellMovieCardRowGap(context).clamp(8.0, 12.0);

  EdgeInsets _gridPadding(BuildContext context) {
    final horizontal = shellHomeSectionHorizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, 4, horizontal, 20);
  }

  int _gridColumns(BoxConstraints constraints, double cardWidth) =>
      (constraints.maxWidth / cardWidth).floor().clamp(1, 8);

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
    if (key.contains('24/7') || key.contains('stream')) {
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
          ShellTvFocusCoordinator.focusFromChipStripDown(
            tabId: _LiveMatchesScreenState._tabId,
            chipRowId: _LiveMatchesScreenState._chipRowId,
            resultsRowId: _LiveMatchesScreenState._gridRowId,
          );
        }
      },
      onLeftEdge: shellTvChipLeftEdge(
        context,
        tabId: _LiveMatchesScreenState._tabId,
        rowId: _LiveMatchesScreenState._chipRowId,
        index: index,
      ),
      onRightEdge: shellTvChipRightEdge(
        tabId: _LiveMatchesScreenState._tabId,
        rowId: _LiveMatchesScreenState._chipRowId,
        index: index,
        itemCount: itemCount,
      ),
      onDownEdge: shellTvChipDownToRow(
        tabId: _LiveMatchesScreenState._tabId,
        chipRowId: _LiveMatchesScreenState._chipRowId,
        resultsRowId: _LiveMatchesScreenState._gridRowId,
      ),
      onUpEdge: () => _s._focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex),
    );
  }

  Widget _buildCenteredSportCircles({
    required ShellMoodCircleLayout layout,
    required int itemCount,
    required bool scaleToFit,
    required bool tvFocus,
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
          ),
        ],
      ],
    );

    return SizedBox(
      height: layout.rowHeight,
      width: double.infinity,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: scaleToFit
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: row,
              )
            : Center(child: row),
      ),
    );
  }
  List<_LiveMatchGridEntry> get _allGridEntries => _sortGridEntriesLiveFirst([
    ..._s._filteredDamiTv.map(_LiveMatchGridEntry.ppv),
    ..._s._filteredStreamed.map(_LiveMatchGridEntry.streamed),
    ..._s._filteredCdnSports.map(_LiveMatchGridEntry.cdnSport),
  ]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_s._tabController != null && _s._sports.isNotEmpty) _buildSportTabs(),
        const SizedBox(height: 2),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    final tvFocus = _tvFocus(context);
    if (tvFocus) {
      shellTvRegisterRow(
        tabId: _LiveMatchesScreenState._tabId,
        rowId: _LiveMatchesScreenState._topBarRowId,
        sortOrder: 0,
        itemCount: _LiveMatchesScreenState._topBarViewIndex + 1,
      );
    }

    final refresh = tvFocus
        ? shellFocusableTap(
            context: context,
            onTap: _s._load,
            borderRadius: 24,
            scaleOnFocus: 1.0,
            focusNode: _s._refreshFocusNode,
            tvTabId: _LiveMatchesScreenState._tabId,
            tvRowId: _LiveMatchesScreenState._topBarRowId,
            tvItemIndex: _LiveMatchesScreenState._topBarRefreshIndex,
            tvZone: ShellTvZone.topBar,
            onDownEdge: _s._topBarDownEdge,
            onLeftEdge: () => _s._focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex),
            onRightEdge: () => _s._focusTopBarItem(_LiveMatchesScreenState._topBarViewIndex),
            onFocusChange: (focused) {
              if (focused) {
                ShellTvFocusCoordinator.saveFocus(
                  _LiveMatchesScreenState._tabId,
                  ShellTvFocusMemory(
                    zone: ShellTvZone.topBar,
                    node: _s._refreshFocusNode,
                  ),
                );
              }
            },
            child: const Tooltip(
              message: 'Refresh',
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.refresh_rounded, color: Colors.white70),
              ),
            ),
          )
        : IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _s._load,
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        10,
        ShellTokens.bodyHorizontalPadding,
        8,
      ),
      child: Row(
        children: [
          _s._serversTopBarButton(),
          const Spacer(),
          refresh,
          const SizedBox(width: 4),
          _buildViewToggle(tvFocus),
        ],
      ),
    );
  }

  Widget _buildViewToggle(bool tvFocus) {
    final isTimeline = _s._view == _LiveMatchesView.timeline;
    final icon = isTimeline
        ? Icons.grid_view_rounded
        : Icons.view_timeline_rounded;
    final tip = isTimeline ? 'Card view' : 'Timeline view';

    if (!tvFocus) {
      return IconButton(
        tooltip: tip,
        icon: Icon(icon, color: Colors.white70),
        onPressed: _s._toggleView,
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: _s._toggleView,
      borderRadius: 24,
      scaleOnFocus: 1.0,
      focusNode: _s._viewFocusNode,
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._topBarRowId,
      tvItemIndex: _LiveMatchesScreenState._topBarViewIndex,
      tvZone: ShellTvZone.topBar,
      onDownEdge: _s._topBarDownEdge,
      onLeftEdge: () =>
          _s._focusTopBarItem(_LiveMatchesScreenState._topBarRefreshIndex),
      onFocusChange: (focused) {
        if (focused) {
          ShellTvFocusCoordinator.saveFocus(
            _LiveMatchesScreenState._tabId,
            ShellTvFocusMemory(
              zone: ShellTvZone.topBar,
              node: _s._viewFocusNode,
            ),
          );
        }
      },
      child: Tooltip(
        message: tip,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildSportTabs() {
    if (_s._tabController == null || _s._sports.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = _s._sports.length + 1;
    final tvFocus = _tvFocus(context);

    return Padding(
      padding: EdgeInsets.only(
        left: ShellTokens.compactChromeLeadingInset(context),
        right: ShellTokens.bodyHorizontalPadding,
        top: 2,
        bottom: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (tvFocus) {
            shellTvRegisterRow(
              tabId: _LiveMatchesScreenState._tabId,
              rowId: _LiveMatchesScreenState._chipRowId,
              sortOrder: _chipSortOrder,
              itemCount: itemCount,
              onFocusUp: () => _s._focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex),
            );
          }

          final layout = ShellMoodCircleLayout.resolve(
            context,
            itemCount: itemCount,
            maxWidth: constraints.maxWidth,
          );

          if (tvFocus) {
            return _buildCenteredSportCircles(
              layout: layout,
              itemCount: itemCount,
              scaleToFit: true,
              tvFocus: tvFocus,
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

          return FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: HorizontalScroller(
              height: layout.rowHeight,
              padding: EdgeInsets.zero,
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(width: layout.horizontalGap),
              itemBuilder: (context, i) => _buildSportCircleItem(
                layout: layout,
                index: i,
                itemCount: itemCount,
                tvFocus: tvFocus,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_s._loading) {
      return Center(
        child: CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
      );
    }
    if (_s._error != null) {
      return ShellErrorRetryPanel(
        message: _s._error!,
        onRetry: _s._load,
        statusIcon: Icons.error_outline,
        buttonIcon: Icons.refresh,
      );
    }
    if (_s._view == _LiveMatchesView.timeline) return _s._buildTimelineBody();
    if (_s._server == _LiveMatchesServer.all) return _buildAllBody();
    if (_s._server == _LiveMatchesServer.ppv) return _buildDamiTvBody();
    if (_s._server == _LiveMatchesServer.streamed) return _buildStreamedBody();
    if (_s._server == _LiveMatchesServer.cdnLive) return _buildCdnBody();

    return const SizedBox.shrink();
  }

  Widget _buildAllBody() {
    final entries = _allGridEntries;
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No streams available',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._registerGridRow(entries.length);
        }
        return GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) => _gridEntryCard(
            entries[i],
            i,
            crossCount,
            _s._gridUpEdge(context, i, crossCount),
          ),
        );
      },
    );
  }

  /// Shared backdrop card for a unified grid entry — reused by the card grid
  /// and the timeline view so both render identical posters/badges.
  Widget _gridEntryCard(
    _LiveMatchGridEntry entry,
    int i,
    int crossCount,
    VoidCallback? upEdge, {
    bool forceActive = false,
    Color? activeBorderColor,
  }) {
    return switch (entry) {
      _LiveMatchGridEntryPpv(:final stream) => _DamiTvMatchCard(
        stream: stream,
        gridIndex: i,
        gridColumns: crossCount,
        onUpEdge: upEdge,
        forceActive: forceActive,
        activeBorderColor: activeBorderColor,
        onTap: () => _s._openDamiTvStream(stream),
      ),
      _LiveMatchGridEntryStreamed(:final match) => _StreamedMatchCard(
        match: match,
        gridIndex: i,
        gridColumns: crossCount,
        onUpEdge: upEdge,
        forceActive: forceActive,
        activeBorderColor: activeBorderColor,
        onTap: () => _s._openStreamedMatch(match),
      ),
      _LiveMatchGridEntryCdnSport(:final event) => _CdnSportCard(
        event: event,
        gridIndex: i,
        gridColumns: crossCount,
        onUpEdge: upEdge,
        forceActive: forceActive,
        activeBorderColor: activeBorderColor,
        onTap: () => _s._openCdnSportEvent(event),
      ),
    };
  }

  Widget _buildStreamedBody() {
    final matches = _s._filteredStreamed;
    if (matches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No streams available',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._registerGridRow(matches.length);
        }
        return GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: matches.length,
          itemBuilder: (context, i) => _StreamedMatchCard(
            match: matches[i],
            gridIndex: i,
            gridColumns: crossCount,
            onUpEdge: _s._gridUpEdge(context, i, crossCount),
            onTap: () => _s._openStreamedMatch(matches[i]),
          ),
        );
      },
    );
  }

  Widget _buildDamiTvBody() {
    final streams = _s._filteredDamiTv;
    if (streams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No streams available',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _s._registerGridRow(streams.length);
        }
        return GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: streams.length,
          itemBuilder: (context, i) => _DamiTvMatchCard(
            stream: streams[i],
            gridIndex: i,
            gridColumns: crossCount,
            onUpEdge: _s._gridUpEdge(context, i, crossCount),
            onTap: () => _s._openDamiTvStream(streams[i]),
          ),
        );
      },
    );
  }

  Widget _buildCdnBody() {
    if (_s._cdnShowChannels) {
      final channels = _s._cdnChannels.where((c) => c.status == 'online').toList();
      if (channels.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'No channels available',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shellHomeSectionHorizontalPadding(context),
              4,
              ShellTokens.bodyHorizontalPadding,
              6,
            ),
            child: Row(
              children: [
                ForjaShellChip(
                  label: '📺 Channels',
                  selected: _s._cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _s._cdnShowChannels = true),
                ),
                const SizedBox(width: 6),
                ForjaShellChip(
                  label: '⚽ Sports',
                  selected: !_s._cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _s._cdnShowChannels = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _channelCardWidth(context);
                final cardHeight = _channelCardHeight(context);
                final gap = _gridGap(context);
                final crossCount = _gridColumns(constraints, cardWidth);
                if (_tvFocus(context)) {
                  _s._registerGridRow(channels.length);
                }
                return GridView.builder(
                  padding: _gridPadding(context),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (context, i) => _CdnChannelCard(
                    channel: channels[i],
                    gridIndex: i,
                    gridColumns: crossCount,
                    onUpEdge: _s._gridUpEdge(context, i, crossCount),
                    onTap: () => _s._openCdnChannel(channels[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    } else {
      final sports = _s._filteredCdnSports;
      if (sports.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'No sports events available',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shellHomeSectionHorizontalPadding(context),
              4,
              ShellTokens.bodyHorizontalPadding,
              6,
            ),
            child: Row(
              children: [
                ForjaShellChip(
                  label: '📺 Channels',
                  selected: _s._cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _s._cdnShowChannels = true),
                ),
                const SizedBox(width: 6),
                ForjaShellChip(
                  label: '⚽ Sports',
                  selected: !_s._cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _s._cdnShowChannels = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _matchCardWidth(context);
                final cardHeight = _matchCardHeight(context);
                final gap = _gridGap(context);
                final crossCount = _gridColumns(constraints, cardWidth);
                if (_tvFocus(context)) {
                  _s._registerGridRow(sports.length);
                }
                return GridView.builder(
                  padding: _gridPadding(context),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  itemCount: sports.length,
                  itemBuilder: (context, i) => _CdnSportCard(
                    event: sports[i],
                    gridIndex: i,
                    gridColumns: crossCount,
                    onUpEdge: _s._gridUpEdge(context, i, crossCount),
                    onTap: () => _s._openCdnSportEvent(sports[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
}
