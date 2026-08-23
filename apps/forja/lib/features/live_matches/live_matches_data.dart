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
    if (server == _LiveMatchesServer.iptvSports) {
      final config = await LiveMatchesIptvSportsConfig.load();
      if (!config.enabled) {
        ForjaToast.info(
          'Enable Forja Sports in Settings → Forja Sports first',
        );
        return;
      }
    }
    final leavingIptv = _s._server == _LiveMatchesServer.iptvSports &&
        server != _LiveMatchesServer.iptvSports;
    setState(() => _s._server = server);
    unawaited(_s._persistServerPreference(server));
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
      ForjaToast.info('Forja Sports needs an Xtream portal');
      return;
    }
    final before = await LiveMatchesIptvSportsConfig.load();
    final next = await LiveMatchesIptvSportsConfig.ensureArmed(
      portalKey: p.key,
    );
    _s._lastSyncedIptvPortalKey = p.key;
    final changed = before.portalKey != next.portalKey ||
        (before.leagues.isEmpty && next.leagues.isNotEmpty);
    if (reload || changed) {
      await _load();
    }
  }

  void _openServerPicker() {
    unawaited(() async {
      await _s._clampServerIfForjaSportsDisabled(reload: true);
      if (!mounted) return;
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
    }());
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
    if (_s._hasCatalogChips) {
      final catalog = ShellTvFocusCoordinator.rowHandle(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._catalogChipRowId,
      );
      if (catalog != null && catalog.itemCount > 0) {
        final idx = catalog.lastFocusedIndex.clamp(0, catalog.itemCount - 1);
        ShellTvFocusCoordinator.focusRowItem(
          _LiveMatchesScreenState._tabId,
          _LiveMatchesScreenState._catalogChipRowId,
          idx,
        );
        return;
      }
    }
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

  /// First grid row ↑ → sport chips → catalog chips → Servers.
  VoidCallback? _gridUpEdge(BuildContext context, int index, int crossCount) {
    if (!_s._tvFocus(context) || index ~/ crossCount != 0) return null;
    return _gridFocusUp;
  }

  void _gridFocusUp() {
    if (_s._hasSportChips) {
      ShellTvFocusCoordinator.focusFromResultsRowUp(
        tabId: _LiveMatchesScreenState._tabId,
        chipRowId: _LiveMatchesScreenState._chipRowId,
      );
      return;
    }
    if (_s._hasCatalogChips) {
      ShellTvFocusCoordinator.focusFromResultsRowUp(
        tabId: _LiveMatchesScreenState._tabId,
        chipRowId: _LiveMatchesScreenState._catalogChipRowId,
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

  void _releaseLiveMatchesItemFocusIfHeld() {
    if (!ShellTvFocusCoordinator.tabHasAttachedFocus(
      _LiveMatchesScreenState._tabId,
    )) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    try {
      primary.unfocus();
    } catch (_) {}
  }

  void _clearTimelineTvRows() {
    _s._timelineTvRowIds.clear();
  }

  Future<void> _load() async {
    if (!mounted || !shellTabVisible) return;
    final iptvConfig = await LiveMatchesIptvSportsConfig.load();
    if (_s._server == _LiveMatchesServer.iptvSports && !iptvConfig.enabled) {
      setState(() => _s._server = _LiveMatchesServer.forjaLive);
      unawaited(_s._persistServerPreference(_LiveMatchesServer.forjaLive));
    }
    _s._loadGen++;
    (this as _LiveMatchesForjaLive)._resetForjaLiveCatalogState();
    _s._resetTimelineLazyState();
    setState(() {
      _s._loading = true;
      _s._error = null;
      _s._sportFilter = 'all';
      _s._timelineAutoScrolled = false;
      _s._damiTvStreams = [];
      _s._streamedMatches = [];
      _s._espnGames = [];
      _s._sports = [];
    });
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    ref.invalidate(liveMatchesPrimaryLoadProvider(_s._server));
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog) {
      (this as _LiveMatchesForjaLive)._kickForjaLiveLazyCatalog();
    }
  }

  void _applyPrimaryLoad(LiveMatchesPrimaryLoad load) {
    final lazyCatalog =
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog;
    final forjaKeep = _s._streamedMatches.where((m) => m.isForjaLive).toList();
    final damiKeep = lazyCatalog ? _s._damiTvStreams : const <_DamiTvStream>[];
    final oldCtrl = _s._tabController;
    setState(() {
      _s._tabController = null;
      _s._damiTvStreams = lazyCatalog ? damiKeep : load.damiTvStreams;
      _s._streamedMatches = lazyCatalog
          ? forjaKeep
          : [...load.streamedMatches, ...forjaKeep];
      _s._espnGames = load.espnGames;
      _s._sports = load.sports;
      _s._loading = false;
      _s._error = null;
      _s._sportFilter = 'all';
      _s._timelineAutoScrolled = false;
    });
    (this as _LiveMatchesForjaLive)._deferTabControllerDispose(oldCtrl);
    if (!mounted) return;
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog &&
        (_s._streamedMatches.any((m) => m.isForjaLive) ||
            _s._damiTvStreams.isNotEmpty)) {
      (this as _LiveMatchesForjaLive)._rebuildSportTabsFromCurrentMatches();
    } else {
      final cats = load.sports;
      final newCtrl = TabController(length: cats.length + 1, vsync: _s);
      newCtrl.addListener(() {
        if (!newCtrl.indexIsChanging) {
          final idx = newCtrl.index;
          _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
        }
      });
      setState(() => _s._tabController = newCtrl);
    }
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    markShellTabFresh();
    if (_s._server == _LiveMatchesServer.all &&
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog) {
      unawaited((this as _LiveMatchesForjaLive)._applyEspnScheduleMerge());
    }
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

  List<_StreamedMatch> get _filteredStreamed => _mergeStreamedCatalogRows(
    _sortStreamedLiveFirst(
      _s._streamedMatches
          .where(
            (m) => _includeInSportFilter(
              category: m.category,
              isAlwaysOn: m.isAlwaysOn,
              sportFilter: _s._sportFilter,
            ),
          )
          .toList(),
    ),
  );

}
