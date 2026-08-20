part of 'live_matches_screen.dart';

mixin _LiveMatchesData
    on ConsumerState<LiveMatchesScreen>, ShellTabRefresh<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  void _focusTopBarItem(int index) {
    if (index == _LiveMatchesScreenState._topBarServersIndex ||
        (_s._showIptvPortalTopBar && index == _s._topBarPortalIndex)) {
      ShellTvFocusCoordinator.focusRowItem(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._topBarRowId,
        index,
      );
      return;
    }
    final node = index == _s._topBarViewIndex
        ? _s._viewFocusNode
        : _s._refreshFocusNode;
    if (!node.canRequestFocus) return;
    node.requestFocus();
    ShellTvFocusCoordinator.saveFocus(
      _LiveMatchesScreenState._tabId,
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: node),
    );
  }

  Future<void> _selectServer(_LiveMatchesServer server) async {
    if (server == _s._server) return;
    final leavingIptv = _s._server == _LiveMatchesServer.iptvSports &&
        server != _LiveMatchesServer.iptvSports;
    setState(() => _s._server = server);
    if (leavingIptv) {
      ref.read(iptvControllerProvider).closePortalPanel();
    }
    if (server == _LiveMatchesServer.iptvSports) {
      final ctrl = ref.read(iptvControllerProvider);
      await ctrl.preparePortalPanel();
      await _syncMyIptvFromActivePortal(ctrl, reload: false);
    }
    await _load();
  }

  Future<void> _syncMyIptvFromActivePortal(
    IptvController ctrl, {
    bool reload = false,
  }) async {
    final p = ctrl.activePortal;
    if (p == null) return;
    if (p.portal.platform != IptvPortalPlatform.xtream) {
      ForjaToast.info('My IPTV needs an Xtream portal');
      return;
    }
    final before = await LiveMatchesIptvSportsConfig.load();
    final next = await LiveMatchesIptvSportsConfig.ensureArmed(
      portalKey: p.key,
    );
    _s._lastSyncedIptvPortalKey = p.key;
    final changed = before.portalKey != next.portalKey ||
        !before.enabled ||
        before.leagues.isEmpty;
    if (reload || changed) {
      await _load();
    }
  }

  void _openServerPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LiveMatchesServerSheet(
        current: _s._server,
        onSelected: (server) {
          Navigator.pop(context);
          unawaited(_selectServer(server));
        },
      ),
    );
  }

  Future<void> _toggleIptvPortalPanel() async {
    final ctrl = ref.read(iptvControllerProvider);
    await ctrl.preparePortalPanel();
    if (!mounted) return;
    ctrl.togglePortalPanel();
  }

  Widget _serversTopBarButton() {
    return _LiveMatchesServersTopBarButton(
      onTap: _openServerPicker,
      onLeftEdge: shellTvNavLeftEdge(
        context,
        listIndex: _LiveMatchesScreenState._topBarServersIndex,
      ),
      onRightEdge: () => _focusTopBarItem(_s._topBarRefreshIndex),
      onDownEdge: _topBarDownEdge,
    );
  }

  Widget _iptvPortalTopBarButton(IptvController ctrl) {
    return IptvPortalsTopBarButton(
      ctrl: ctrl,
      onTogglePanel: () => unawaited(_toggleIptvPortalPanel()),
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._topBarRowId,
      tvItemIndex: _s._topBarPortalIndex,
      onLeftEdge: () => _focusTopBarItem(_s._topBarRefreshIndex),
      onRightEdge: () {},
      onDownEdge: _topBarDownEdge,
    );
  }

  void _topBarDownEdge() {
    if (_s._hasSportChips) {
      final chip = ShellTvFocusCoordinator.rowHandle(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._chipRowId,
      );
      if (chip != null && chip.itemCount > 0) {
        final idx = chip.lastFocusedIndex.clamp(0, chip.itemCount - 1);
        ShellTvFocusCoordinator.focusRowItem(
          _LiveMatchesScreenState._tabId,
          _LiveMatchesScreenState._chipRowId,
          idx,
        );
        return;
      }
    }
    _restoreLiveMatchesTvFocus();
  }

  /// First grid row ↑ → CDN mode chips (if present) → sport chips → Servers.
  VoidCallback? _gridUpEdge(BuildContext context, int index, int crossCount) {
    if (!_s._tvFocus(context) || index ~/ crossCount != 0) return null;
    return _gridFocusUp;
  }

  void _gridFocusUp() {
    final cdn = ShellTvFocusCoordinator.rowHandle(
      _LiveMatchesScreenState._tabId,
      _LiveMatchesScreenState._cdnModeRowId,
    );
    if (cdn != null && cdn.itemCount > 0) {
      final idx = cdn.lastFocusedIndex.clamp(0, cdn.itemCount - 1);
      ShellTvFocusCoordinator.focusRowItem(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._cdnModeRowId,
        idx,
      );
      return;
    }
    if (_s._hasSportChips) {
      ShellTvFocusCoordinator.focusFromResultsRowUp(
        tabId: _LiveMatchesScreenState._tabId,
        chipRowId: _LiveMatchesScreenState._chipRowId,
      );
      return;
    }
    _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex);
  }

  bool _focusGridItem(int index) {
    final handle = ShellTvFocusCoordinator.rowHandle(
      _LiveMatchesScreenState._tabId,
      _LiveMatchesScreenState._gridRowId,
    );
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = index.clamp(0, handle.itemCount - 1);
    return ShellTvFocusCoordinator.focusRowItem(
      _LiveMatchesScreenState._tabId,
      _LiveMatchesScreenState._gridRowId,
      idx,
    );
  }

  bool _restoreLiveMatchesTvFocus() {
    bool tryFocus() {
      final grid = ShellTvFocusCoordinator.rowHandle(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._gridRowId,
      );
      if (grid != null && grid.itemCount > 0) {
        final idx = grid.lastFocusedIndex.clamp(0, grid.itemCount - 1);
        return _focusGridItem(idx);
      }
      for (final rowId in _s._timelineTvRowIds) {
        final handle = ShellTvFocusCoordinator.rowHandle(
          _LiveMatchesScreenState._tabId,
          rowId,
        );
        if (handle == null || handle.itemCount <= 0) continue;
        final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
        return ShellTvFocusCoordinator.focusRowItem(
          _LiveMatchesScreenState._tabId,
          rowId,
          idx,
        );
      }
      return false;
    }

    if (tryFocus()) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ShellTvFocus.currentNavTabId != _LiveMatchesScreenState._tabId) {
        return;
      }
      tryFocus();
    });
    return false;
  }

  void _clearTimelineTvRows() {
    _s._timelineTvRowIds.clear();
  }

  Future<void> _load() async {
    if (!mounted || !shellTabVisible) return;
    _s._loadGen++;
    setState(() {
      _s._loading = true;
      _s._error = null;
      _s._sportFilter = 'all';
      _s._timelineAutoScrolled = false;
    });
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    ref.invalidate(liveMatchesPrimaryLoadProvider(_s._server));
  }

  void _applyPrimaryLoad(LiveMatchesPrimaryLoad load) {
    final oldCtrl = _s._tabController;
    setState(() {
      _s._tabController = null;
      _s._damiTvStreams = load.damiTvStreams;
      _s._streamedMatches = load.streamedMatches;
      _s._cdnChannels = load.cdnChannels;
      _s._cdnSports = load.cdnSports;
      _s._sports = load.sports;
      _s._loading = false;
      _s._error = null;
      _s._sportFilter = 'all';
      _s._timelineAutoScrolled = false;
    });
    oldCtrl?.dispose();
    if (!mounted) return;
    final cats = load.sports;
    final newCtrl = TabController(length: cats.length + 1, vsync: _s);
    newCtrl.addListener(() {
      if (!newCtrl.indexIsChanging) {
        final idx = newCtrl.index;
        _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
      }
    });
    setState(() => _s._tabController = newCtrl);
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    markShellTabFresh();
  }

  /// Sport chip / tab change rebuilds the time canvas - re-land on now.
  void _setSportFilter(String id) {
    setState(() {
      _s._sportFilter = id;
      _s._timelineAutoScrolled = false;
    });
  }

  List<_DamiTvStream> get _filteredDamiTv => _sortDamiTvLiveFirst(
    _s._damiTvStreams
        .where(
          (s) => _includeInSportFilter(
            category: s.categoryName,
            isAlwaysOn: s.isAlwaysOn,
            sportFilter: _s._sportFilter,
          ),
        )
        .toList(),
  );

  List<_StreamedMatch> get _filteredStreamed => _sortStreamedLiveFirst(
    _s._streamedMatches
        .where(
          (m) => _includeInSportFilter(
            category: m.category,
            isAlwaysOn: m.isAlwaysOn,
            sportFilter: _s._sportFilter,
          ),
        )
        .toList(),
  );

  List<_CdnSportEvent> get _filteredCdnSports => _sortCdnSportsLiveFirst(
    _s._cdnSports.where((s) {
      // All-servers uses sport buckets; CDN-only still filters by tournament.
      if (_s._server == _LiveMatchesServer.all) {
        return _includeInSportFilter(
          category: s.sport,
          isAlwaysOn: false,
          sportFilter: _s._sportFilter,
        );
      }
      if (_s._sportFilter == 'all') {
        // CDN-only: tournaments are not the 24/7 sport chip - keep all.
        return true;
      }
      return s.tournament == _s._sportFilter;
    }).toList(),
  );
}
