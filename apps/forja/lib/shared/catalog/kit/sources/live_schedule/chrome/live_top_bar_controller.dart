part of '../live_sports_hub_page.dart';

mixin _LiveMatchesData
    on ConsumerState<LiveSportsHubPage>, ShellTabRefresh<LiveSportsHubPage> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  bool get _tvFocusEnabled =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _scheduleRestoreCatalogTopBarFocus() {
    if (!_tvFocusEnabled) return;
    void attempt() {
      if (!mounted) return;
      _focusTopBarItem(_s._topBarCatalogIndex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt();
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    });
  }

  /// Re-land on the last grid / chip / timeline row after lazy catalog
  /// setStates — sport-tab remounts release item focus but keep row memory.
  void _scheduleRestoreLiveMatchesTvFocus() {
    if (!_tvFocusEnabled) return;
    if (!(this as ShellTabRefresh<LiveSportsHubPage>).shellTabVisible) return;

    void attempt() {
      if (!mounted) return;
      if (ShellTvFocus.currentNavTabId != _LiveMatchesScreenState._tabId) {
        return;
      }
      if (ShellTvFocusCoordinator.tabHasAttachedFocus(
        _LiveMatchesScreenState._tabId,
      )) {
        return;
      }
      _restoreLiveMatchesTvFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt();
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    });
  }

  void _focusTopBarItem(int index) {
    if ((_s._showCatalogTopBar && index == _s._topBarCatalogIndex) ||
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

  Future<void> _syncMyIptvFromActivePortal(
    IptvController ctrl, {
    bool reload = false,
  }) async {
    final p = ctrl.activePortal;
    if (p == null) return;
    if (!p.portal.platform.supportsForjaSports) {
      // Record the key so IPTV controller noise (channel select, health, …)
      // does not re-toast for the same unsupported portal.
      final alreadyWarned = _s._lastSyncedIptvPortalKey == p.key;
      _s._lastSyncedIptvPortalKey = p.key;
      if (!alreadyWarned) {
        ForjaToast.info('Forja Sports needs an Xtream or Stalker portal');
      }
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
    unawaited(_liveBroadcastIndexCached());
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
          builder: (_) => _LiveMatchesScheduleSheet(
            status: _s._scheduleStatus,
            horizon: _s._scheduleHorizon,
            onChanged: ({
              _LiveMatchesScheduleStatus? status,
              _LiveMatchesScheduleHorizon? horizon,
            }) {
              (this as _LiveMatchesForjaLive)._setScheduleFilter(
                status: status,
                horizon: horizon,
              );
            },
          ),
        );
      } finally {
        _s._topBarSheetOpen = false;
      }
    }());
  }

  void _toggleIptvPortalPanel() {
    ref.read(iptvControllerProvider).togglePortalPanel();
  }

  String get _catalogTopBarLabel {
    final filter = _s._forjaLivePluginFilter;
    if (filter.isEmpty || filter == 'all') {
      return (this as _LiveMatchesForjaLive)._defaultForjaLiveCatalogLabel() ??
          'Catalog';
    }
    return (this as _LiveMatchesForjaLive)._forjaLivePluginLoadForFilter(filter)
            ?.label ??
        _liveForjaPluginDisplayName(filter);
  }

  Widget _catalogTopBarButton() {
    return _LiveMatchesTopBarActionButton(
      label: _catalogTopBarLabel,
      icon: Icons.video_library_rounded,
      accent: false,
      tvItemIndex: _s._topBarCatalogIndex,
      onTap: _openCatalogPicker,
      onLeftEdge: shellTvNavLeftEdge(
        context,
        listIndex: _s._topBarCatalogIndex,
      ),
      onRightEdge: () => _focusTopBarItem(
        _s._showTimeTopBar ? _s._topBarTimeIndex : _s._topBarRefreshIndex,
      ),
      onDownEdge: _topBarDownEdge,
    );
  }

  Widget _timeTopBarButton() {
    return _LiveMatchesTopBarActionButton(
      label: _liveMatchesScheduleChipLabel(
        status: _s._scheduleStatus,
        horizon: _s._scheduleHorizon,
      ),
      icon: Icons.schedule_rounded,
      accent: false,
      tvItemIndex: _s._topBarTimeIndex,
      onTap: _openTimeWindowPicker,
      onLeftEdge: () => _focusTopBarItem(
        _s._showCatalogTopBar
            ? _s._topBarCatalogIndex
            : _s._topBarRefreshIndex,
      ),
      onRightEdge: () => _focusTopBarItem(_s._topBarRefreshIndex),
      onDownEdge: _topBarDownEdge,
    );
  }

  Widget _iptvPortalTopBarButton(IptvController ctrl) {
    return IptvPortalsTopBarButton(
      ctrl: ctrl,
      onTogglePanel: _toggleIptvPortalPanel,
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
    _focusTopBarItem(_s._topBarRefreshIndex);
  }

  /// First grid row ↑ → sport chips → Catalog / Time.
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
    _focusTopBarItem(_s._topBarRefreshIndex);
  }

  bool get _applyTimeWindowFilter => _s._showCatalogTopBar;

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
          !(this as _LiveMatchesForjaLive)._forjaLiveCatalogBusy);

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
    if (_s._server != _LiveMatchesServer.forjaLive) {
      setState(() => _s._server = _LiveMatchesServer.forjaLive);
      unawaited(_s._persistServerPreference(_LiveMatchesServer.forjaLive));
    }
    if (_s._iptvSportsEnabled != iptvConfig.enabled) {
      setState(() => _s._iptvSportsEnabled = iptvConfig.enabled);
    }
    final lazyCatalog =
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog;
    _s._loadGen++;
    (this as _LiveMatchesForjaLive)._resetForjaLiveCatalogState(
      clearMatches: !lazyCatalog,
    );
    _s._resetTimelineLazyState();
    setState(() {
      (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
      _s._loading = !lazyCatalog;
      // Keep spinner until discovery marks plugins loading — do not sync yet
      // (empty plugin map would clear hydrating and flash the empty panel).
      if (lazyCatalog) _s._forjaLiveCatalogHydrating = true;
      _s._error = null;
      _s._sportFilter = 'all';
      _s._timelineAutoScrolled = false;
      if (!lazyCatalog) {
        _s._iframeCatalogStreams = [];
        _s._streamedMatches = [];
        _s._espnGames = [];
        _s._sports = [];
      } else {
        final oldCtrl = _s._tabController;
        _s._tabController = null;
        _s._sports = [];
        (this as _LiveMatchesForjaLive)._deferTabControllerDispose(oldCtrl);
      }
    });
    _scheduleRestoreRefreshFocus();
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    ref.invalidate(liveMatchesPrimaryLoadProvider(_s._server));
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog) {
      (this as _LiveMatchesForjaLive)._kickForjaLiveLazyCatalog(replace: true);
    }
  }

  void _applyPrimaryLoad(_LiveMatchesPrimaryLoad load) {
    final lazyCatalog =
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog;
    final forjaKeep = _s._streamedMatches.where((m) => m.isForjaLive).toList();
    final damiKeep = lazyCatalog ? _s._iframeCatalogStreams : const <_IframeCatalogStream>[];
    final oldCtrl = _s._tabController;
    setState(() {
      (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
      _s._tabController = null;
      _s._iframeCatalogStreams = lazyCatalog ? damiKeep : load.iframeCatalogStreams;
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
            _s._iframeCatalogStreams.isNotEmpty)) {
      (this as _LiveMatchesForjaLive)._rebuildSportTabsFromCurrentMatches();
    } else {
      final cats = load.sports;
      if (cats.length > 1) {
        final newCtrl = TabController(length: cats.length + 1, vsync: _s);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            _setSportFilter(idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        setState(() => _s._tabController = newCtrl);
      } else {
        setState(() => _s._tabController = null);
      }
    }
    if (_s._timelineScrollController.hasClients) {
      _s._timelineScrollController.jumpTo(0);
    }
    markShellTabFresh();
    _scheduleRestoreRefreshFocus(clearWhenSettled: true);
    _scheduleRestoreLiveMatchesTvFocus();
    if (_s._server == _LiveMatchesServer.forjaLive &&
        (this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog) {
      unawaited((this as _LiveMatchesForjaLive)._applyScheduleEnrichMerge());
    }
  }

  /// Sport chip / tab change rebuilds the time canvas - re-land on now.
  void _setSportFilter(String id) {
    setState(() {
      (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
      _s._sportFilter = id;
      _s._timelineAutoScrolled = false;
    });
  }

  List<_IframeCatalogStream> get _filteredIframeCatalog {
    var list = _s._iframeCatalogStreams
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
          .where(
            (s) => _iframeCatalogInScheduleFilter(
              s,
              status: _s._scheduleStatus,
              horizon: _s._scheduleHorizon,
            ),
          )
          .toList();
    }
    return _sortIframeCatalogLiveFirst(list);
  }

  List<_StreamedMatch> _streamedMatchesSportAndTimeFiltered() {
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
          .where(
            (m) => _streamedMatchInScheduleFilter(
              m,
              status: _s._scheduleStatus,
              horizon: _scheduleHorizonForCatalogMatch(
                m,
                horizon: _s._scheduleHorizon,
                catalogFilter: _s._forjaLivePluginFilter,
              ),
            ),
          )
          .toList();
    }
    return list;
  }

  List<_StreamedMatch> get _filteredStreamed =>
      _mergeStreamedCatalogRows(
        _sortStreamedLiveFirst(_streamedMatchesSportAndTimeFiltered()),
      );

}
