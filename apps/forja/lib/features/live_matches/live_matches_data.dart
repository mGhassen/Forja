part of 'live_matches_screen.dart';

mixin _LiveMatchesData
    on ConsumerState<LiveMatchesScreen>, ShellTabRefresh<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  bool get _tvFocusEnabled =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _scheduleRestoreServersTopBarFocus() {
    if (!_tvFocusEnabled) return;
    void attempt() {
      if (!mounted) return;
      _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt();
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    });
  }

  void _focusTopBarItem(int index) {
    if (index == _LiveMatchesScreenState._topBarServersIndex ||
        (_s._showCatalogTopBar && index == _s._topBarCatalogIndex) ||
        (_s._showTimeTopBar && index == _s._topBarTimeIndex) ||
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

  /// Forja Live / Forja Sports (/ All) share the Catalog JS schedule — only play
  /// routing differs. Switching among them must not wipe or re-scrape the grid.
  bool _sharesLiveCatalogSchedule(
    _LiveMatchesServer a,
    _LiveMatchesServer b,
  ) {
    bool shared(_LiveMatchesServer s) =>
        s == _LiveMatchesServer.all ||
        s == _LiveMatchesServer.forjaLive ||
        s == _LiveMatchesServer.iptvSports;
    return shared(a) && shared(b);
  }

  Future<void> _selectServer(_LiveMatchesServer server) async {
    if (server == _s._server) return;
    if (server == _LiveMatchesServer.iptvSports) {
      final config = await LiveMatchesIptvSportsConfig.load();
      if (!config.enabled) {
        ForjaToast.info(
          'Enable Forja Sports in Settings → Forja Sports first',
        );
        _scheduleRestoreServersTopBarFocus();
        return;
      }
    }
    final previous = _s._server;
    final keepSchedule = _sharesLiveCatalogSchedule(previous, server);
    final leavingIptv = previous == _LiveMatchesServer.iptvSports &&
        server != _LiveMatchesServer.iptvSports;
    setState(() => _s._server = server);
    unawaited(_s._persistServerPreference(server));
    if (leavingIptv) {
      ref.read(iptvControllerProvider).closePortalPanel();
    }
    if (server == _LiveMatchesServer.iptvSports) {
      final ctrl = ref.read(iptvControllerProvider);
      await ctrl.preparePortalPanel();
      // May _load() if portal/leagues actually changed — otherwise keep grid.
      await _syncMyIptvFromActivePortal(ctrl, reload: false);
    }
    if (keepSchedule) {
      _scheduleRestoreServersTopBarFocus();
      return;
    }
    await _load();
    _scheduleRestoreServersTopBarFocus();
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
    if (_s._topBarSheetOpen) return;
    _s._topBarSheetOpen = true;
    unawaited(() async {
      try {
        final avail =
            await _s._clampServerIfForjaSportsDisabled(reload: false);
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: const Color(0xFF141414),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _LiveMatchesServerSheet(
            current: _s._server,
            iptvSportsEnabled: avail.iptvSportsEnabled,
            stremioLiveEnabled: avail.stremioLiveEnabled,
            onSelected: (server) {
              Navigator.pop(context);
              unawaited(_selectServer(server));
            },
          ),
        );
      } finally {
        _s._topBarSheetOpen = false;
      }
    }());
  }

  void _openCatalogPicker() {
    if (_s._topBarSheetOpen) return;
    final loads = _s._forjaLivePluginLoads.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    if (loads.isEmpty) return;
    _s._topBarSheetOpen = true;
    unawaited(() async {
      try {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: const Color(0xFF141414),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _LiveMatchesCatalogSheet(
            current: _s._forjaLivePluginFilter,
            catalogs: loads,
            onSelected: (filter) {
              Navigator.pop(context);
              (this as _LiveMatchesForjaLive)._setForjaLivePluginFilter(filter);
            },
          ),
        );
      } finally {
        _s._topBarSheetOpen = false;
      }
    }());
  }

  void _openTimeWindowPicker() {
    if (_s._topBarSheetOpen) return;
    _s._topBarSheetOpen = true;
    unawaited(() async {
      try {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: const Color(0xFF141414),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _LiveMatchesTimeWindowSheet(
            current: _s._timeWindow,
            onSelected: (window) {
              Navigator.pop(context);
              (this as _LiveMatchesForjaLive)._setTimeWindow(window);
            },
          ),
        );
      } finally {
        _s._topBarSheetOpen = false;
      }
    }());
  }

  Future<void> _toggleIptvPortalPanel() async {
    final ctrl = ref.read(iptvControllerProvider);
    await ctrl.preparePortalPanel();
    if (!mounted) return;
    ctrl.togglePortalPanel();
  }

  String get _catalogTopBarLabel {
    final filter = _s._forjaLivePluginFilter;
    if (filter == 'all') return 'All';
    return _s._forjaLivePluginLoads[filter]?.label ??
        _liveForjaPluginDisplayName(filter);
  }

  Widget _serversTopBarButton() {
    return _LiveMatchesTopBarActionButton(
      label: _liveMatchesServerLabel(_s._server),
      icon: Icons.dns_rounded,
      accent: false,
      tvItemIndex: _LiveMatchesScreenState._topBarServersIndex,
      onTap: _openServerPicker,
      onLeftEdge: shellTvNavLeftEdge(
        context,
        listIndex: _LiveMatchesScreenState._topBarServersIndex,
      ),
      onRightEdge: () => _focusTopBarItem(_s._topBarRightOfServersIndex),
      onDownEdge: _topBarDownEdge,
    );
  }

  int get _topBarRightOfServersIndex {
    if (_s._showCatalogTopBar) return _s._topBarCatalogIndex;
    if (_s._showTimeTopBar) return _s._topBarTimeIndex;
    return _s._topBarRefreshIndex;
  }

  Widget _catalogTopBarButton() {
    return _LiveMatchesTopBarActionButton(
      label: _catalogTopBarLabel,
      icon: Icons.video_library_rounded,
      accent: false,
      tvItemIndex: _s._topBarCatalogIndex,
      onTap: _openCatalogPicker,
      onLeftEdge: () =>
          _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex),
      onRightEdge: () => _focusTopBarItem(
        _s._showTimeTopBar ? _s._topBarTimeIndex : _s._topBarRefreshIndex,
      ),
      onDownEdge: _topBarDownEdge,
    );
  }

  Widget _timeTopBarButton() {
    return _LiveMatchesTopBarActionButton(
      label: _liveMatchesTimeWindowLabel(_s._timeWindow),
      icon: Icons.schedule_rounded,
      accent: false,
      tvItemIndex: _s._topBarTimeIndex,
      onTap: _openTimeWindowPicker,
      onLeftEdge: () => _focusTopBarItem(
        _s._showCatalogTopBar
            ? _s._topBarCatalogIndex
            : _LiveMatchesScreenState._topBarServersIndex,
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

  /// Sport chips ↑ → top-bar Servers / Catalog / Time (never a picker sheet row).
  void _focusFromSportChipsUp() {
    final top = ShellTvFocusCoordinator.rowHandle(
      _LiveMatchesScreenState._tabId,
      _LiveMatchesScreenState._topBarRowId,
    );
    if (top != null && top.itemCount > 0) {
      final idx = top.lastFocusedIndex.clamp(0, top.itemCount - 1);
      if (ShellTvFocusCoordinator.focusRowItem(
        _LiveMatchesScreenState._tabId,
        _LiveMatchesScreenState._topBarRowId,
        idx,
      )) {
        return;
      }
    }
    if (_s._showTimeTopBar) {
      _focusTopBarItem(_s._topBarTimeIndex);
      return;
    }
    if (_s._showCatalogTopBar) {
      _focusTopBarItem(_s._topBarCatalogIndex);
      return;
    }
    _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex);
  }

  /// First grid row ↑ → sport chips → Servers / Catalog.
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
    if (_s._showTimeTopBar) {
      _focusTopBarItem(_s._topBarTimeIndex);
      return;
    }
    if (_s._showCatalogTopBar) {
      _focusTopBarItem(_s._topBarCatalogIndex);
      return;
    }
    _focusTopBarItem(_LiveMatchesScreenState._topBarServersIndex);
  }

  bool get _applyTimeWindowFilter =>
      _s._server == _LiveMatchesServer.all ||
      _s._server == _LiveMatchesServer.forjaLive ||
      _s._server == _LiveMatchesServer.iptvSports;

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
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    // Sport-chip remount disposes chip nodes — only release those.
    // Keep top-bar Refresh / view toggle through catalog reload.
    if (identical(primary, _s._refreshFocusNode) ||
        identical(primary, _s._viewFocusNode)) {
      return;
    }
    if (!ShellTvFocusCoordinator.tabHasAttachedFocus(
      _LiveMatchesScreenState._tabId,
    )) {
      return;
    }
    try {
      primary.unfocus();
    } catch (_) {}
  }

  void _onTopBarRefreshPressed() {
    if (_s._tvFocus(context)) {
      _s._restoreRefreshFocus = true;
    }
    unawaited(_load());
  }

  bool get _refreshFocusRestoreSettled =>
      !_s._loading &&
      (!(this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog ||
          !(this as _LiveMatchesForjaLive)._forjaLiveAnyLoading);

  void _scheduleRestoreRefreshFocus({bool clearWhenSettled = false}) {
    if (!_s._restoreRefreshFocus) return;
    void attempt({required bool clear}) {
      if (!mounted || !_s._restoreRefreshFocus) return;
      final node = _s._refreshFocusNode;
      if (node.canRequestFocus && !node.hasFocus) {
        node.requestFocus();
        ShellTvFocusCoordinator.saveFocus(
          _LiveMatchesScreenState._tabId,
          ShellTvFocusMemory(zone: ShellTvZone.topBar, node: node),
        );
      }
      if (clear && _refreshFocusRestoreSettled) {
        _s._restoreRefreshFocus = false;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt(clear: false);
      // Beat empty-panel / chip remount autofocus on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt(clear: clearWhenSettled);
      });
    });
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
    _scheduleRestoreRefreshFocus();
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
    _scheduleRestoreRefreshFocus(clearWhenSettled: true);
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

  List<_DamiTvStream> get _filteredDamiTv {
    var list = _s._damiTvStreams
        .where(
          (s) => _includeInSportFilter(
            category: s.categoryName,
            isAlwaysOn: s.isAlwaysOn,
            sportFilter: _s._sportFilter,
          ),
        )
        .toList();
    if (_applyTimeWindowFilter) {
      list = list
          .where((s) => _damiTvInTimeWindow(s, _s._timeWindow))
          .toList();
    }
    return _sortDamiTvLiveFirst(list);
  }

  List<_StreamedMatch> get _filteredStreamed {
    var list = _s._streamedMatches
        .where(
          (m) => _includeInSportFilter(
            category: m.category,
            isAlwaysOn: m.isAlwaysOn,
            sportFilter: _s._sportFilter,
          ),
        )
        .toList();
    if (_applyTimeWindowFilter) {
      list = list
          .where((m) => _streamedMatchInTimeWindow(m, _s._timeWindow))
          .toList();
    }
    return _mergeStreamedCatalogRows(_sortStreamedLiveFirst(list));
  }

}
