part of 'live_matches_screen.dart';

class _ForjaLivePluginLoad {
  const _ForjaLivePluginLoad({
    required this.pluginId,
    required this.label,
    this.loading = false,
    this.attempted = false,
    this.matchCount = 0,
    this.error,
  });

  final String pluginId;
  final String label;
  final bool loading;
  final bool attempted;
  final int matchCount;
  final String? error;

  _ForjaLivePluginLoad copyWith({
    bool? loading,
    bool? attempted,
    int? matchCount,
    String? error,
  }) => _ForjaLivePluginLoad(
    pluginId: pluginId,
    label: label,
    loading: loading ?? this.loading,
    attempted: attempted ?? this.attempted,
    matchCount: matchCount ?? this.matchCount,
    error: error,
  );
}

mixin _LiveMatchesForjaLive
    on ConsumerState<LiveMatchesScreen>, _LiveMatchesData {
  @override
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  bool get _usesForjaLiveLazyCatalog =>
      _s._server == _LiveMatchesServer.all ||
      _s._server == _LiveMatchesServer.forjaLive ||
      _s._server == _LiveMatchesServer.iptvSports;

  bool get _showForjaLiveCatalogChrome =>
      _usesForjaLiveLazyCatalog && _s._forjaLivePluginLoads.isNotEmpty;

  bool get _forjaLiveAnyLoading =>
      _s._forjaLivePluginLoads.values.any((e) => e.loading);

  bool _forjaLiveMatchPlayable(_StreamedMatch match) {
    return !_forjaLiveAnyLoading && match.isLive;
  }

  List<_StreamedMatch> get _displayStreamedMatches {
    var list = (this as _LiveMatchesData)._filteredStreamed;
    if (_s._server == _LiveMatchesServer.forjaLive) {
      list = list.where((m) => !m.isIptvSports).toList();
    }
    if (_showForjaLiveCatalogChrome && _s._forjaLivePluginFilter != 'all') {
      list = list
          .where(
            (m) => _streamedMatchesForEvent(m, _s._streamedMatches).any(
              (row) => row.livePluginId == _s._forjaLivePluginFilter,
            ),
          )
          .toList();
    }
    return list;
  }

  ({List<_DamiTvStream> ppv, List<_StreamedMatch> streamed})
  _catalogFilteredGridSources() {
    var ppv = (this as _LiveMatchesData)._filteredDamiTv;
    var streamed = (this as _LiveMatchesData)._filteredStreamed;
    if (!_showForjaLiveCatalogChrome || _s._forjaLivePluginFilter == 'all') {
      return (ppv: ppv, streamed: streamed);
    }
    final filter = _s._forjaLivePluginFilter;
    if (LiveMatchesEngine.cachedIsNativeUnlock(filter, 'ppv')) {
      return (ppv: ppv, streamed: []);
    }
    streamed = streamed
        .where(
          (m) => _streamedMatchesForEvent(m, _s._streamedMatches).any(
            (row) => row.livePluginId == filter,
          ),
        )
        .toList();
    return (ppv: [], streamed: streamed);
  }

  void _resetForjaLiveCatalogState() {
    EngineService.instance.cancelLiveCatalog();
    _s._forjaLiveLoadGen++;
    _s._forjaLivePluginLoads = {};
    _s._damiTvStreams = [];
    _s._streamedMatches = _s._streamedMatches
        .where((m) => !m.isForjaLive)
        .toList();
    _s._eventStreamViewerTotals.clear();
  }

  Future<void> _restoreForjaLiveCatalogFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(
      _LiveMatchesScreenState._forjaLiveCatalogFilterPreferenceKey,
    );
    if (saved == null || saved.isEmpty) return;
    if (!mounted) return;
    setState(() => _s._forjaLivePluginFilter = saved);
  }

  Future<void> _persistForjaLiveCatalogFilterPreference(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _LiveMatchesScreenState._forjaLiveCatalogFilterPreferenceKey,
      filter,
    );
  }

  void _setForjaLivePluginFilter(String filter) {
    if (_s._forjaLivePluginFilter == filter) return;
    setState(() => _s._forjaLivePluginFilter = filter);
    unawaited(_persistForjaLiveCatalogFilterPreference(filter));
    // Do not cancel in-flight catalog scrapes — finished rows stay cached
    // (`attempted`) so switching catalogs / All never re-fetches.
    _kickForjaLiveLazyCatalog();
  }

  Future<void> _restoreTimeWindowPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_LiveMatchesScreenState._schedulePreferenceKey) ??
        prefs.getString(_LiveMatchesScreenState._timeWindowPreferenceKeyLegacy);
    final saved = _liveMatchesScheduleFromPref(raw);
    if (saved == null) return;
    if (!mounted) return;
    setState(() {
      _s._scheduleStatus = saved.status;
      _s._scheduleHorizon = saved.horizon;
      _s._catalogFetchedHorizon = saved.horizon;
    });
    unawaited(
      _persistSchedulePreference(
        status: saved.status,
        horizon: saved.horizon,
      ),
    );
  }

  Future<void> _persistSchedulePreference({
    required _LiveMatchesScheduleStatus status,
    required _LiveMatchesScheduleHorizon horizon,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _LiveMatchesScreenState._schedulePreferenceKey,
      _liveMatchesSchedulePref(status: status, horizon: horizon),
    );
  }

  void _setScheduleFilter({
    _LiveMatchesScheduleStatus? status,
    _LiveMatchesScheduleHorizon? horizon,
  }) {
    final nextStatus = status ?? _s._scheduleStatus;
    final nextHorizon = horizon ?? _s._scheduleHorizon;
    if (nextStatus == _s._scheduleStatus &&
        nextHorizon == _s._scheduleHorizon) {
      return;
    }
    final widen = _liveMatchesScheduleHorizonRank(nextHorizon) >
        _liveMatchesScheduleHorizonRank(_s._catalogFetchedHorizon);
    setState(() {
      _s._scheduleStatus = nextStatus;
      _s._scheduleHorizon = nextHorizon;
    });
    unawaited(
      _persistSchedulePreference(status: nextStatus, horizon: nextHorizon),
    );
    if (widen) {
      _refetchCatalogsForWiderHorizon(nextHorizon);
    } else {
      _rebuildSportTabsFromCurrentMatches();
    }
  }

  void _refetchCatalogsForWiderHorizon(_LiveMatchesScheduleHorizon horizon) {
    _resetForjaLiveCatalogState();
    _s._catalogFetchedHorizon = horizon;
    _kickForjaLiveLazyCatalog();
  }

  void _ensureForjaLivePluginFilterValid() {
    if (_s._forjaLivePluginFilter == 'all') return;
    if (!_s._forjaLivePluginLoads.containsKey(_s._forjaLivePluginFilter)) {
      _setForjaLivePluginFilter('all');
    }
  }

  void _kickForjaLiveLazyCatalog() {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!(this as ShellTabRefresh<LiveMatchesScreen>).shellTabVisible) return;
    if (!_s._serverHydrated) return;
    unawaited(_loadForjaLiveCatalogLazy());
  }

  void _applyEngineCatalogSettingsChange({required bool reloadNow}) {
    if (!_usesForjaLiveLazyCatalog) return;
    _resetForjaLiveCatalogState();
    if (!reloadNow) {
      _s._forjaLiveCatalogSettingsDirty = true;
      if (mounted) setState(() {});
      return;
    }
    _s._forjaLiveCatalogSettingsDirty = false;
    if (mounted) setState(() {});
    _kickForjaLiveLazyCatalog();
  }

  Future<bool> _isEspnCatalogEnabled() async {
    await EngineService.instance.ensureOfficialInstalled();
    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (p.id == 'catalog-espn') return pack.isPluginActive(p);
      }
    }
    return false;
  }

  void _syncEspnGamesFromStreamed() {
    _s._espnGames = [
      for (final m in _s._streamedMatches)
        if (m.id.startsWith('espn:') && m.sportMatchGame != null)
          Map<String, dynamic>.from(m.sportMatchGame!),
    ];
  }

  bool _shouldRunEspnScheduleMerge() {
    if (_s._forjaLivePluginFilter == 'all') return true;
    if (_s._forjaLivePluginFilter == 'catalog-espn') return true;
    final espnLoad = _s._forjaLivePluginLoads['catalog-espn'];
    return espnLoad?.attempted == true;
  }

  /// Enrich other catalog rows with ESPN teams; ESPN catalog rows load separately.
  Future<void> _applyEspnScheduleMerge() async {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!mounted) return;
    if (!_shouldRunEspnScheduleMerge()) return;
    if (_s._server == _LiveMatchesServer.forjaLive && _forjaLiveAnyLoading) {
      return;
    }
    if (!await _isEspnCatalogEnabled()) return;

    var espn = _s._espnGames;
    if (espn.isEmpty) {
      espn = await _fetchEspnSportMatchGames();
    }
    if (!mounted) return;

    final base = _stripEspnMergedScheduleRows(_s._streamedMatches);
    final merged = _mergeStreamedWithEspn(
      base,
      espn,
      appendUnmatched: _s._server != _LiveMatchesServer.forjaLive,
    );
    setState(() {
      _s._streamedMatches = merged.streamed;
      _s._espnGames = merged.espnGames;
    });
    _rebuildSportTabsFromCurrentMatches();
  }

  Future<Map<String, dynamic>> _liveCatalogExtraConfig(
    EnginePlugin catalog,
  ) async {
    if (catalog.id != 'catalog-espn') return const {};
    final sportsConfig = await LiveMatchesIptvSportsConfig.load();
    final leagues = sportsConfig.leagues.isEmpty
        ? LiveMatchesIptvSportsConfig.allLeagues
        : sportsConfig.leagues;
    return {'leagues': leagues, 'providerId': 'catalog-espn'};
  }

  void _ensureForjaLivePluginLoadsRegistered(List<EnginePlugin> catalogPlugins) {
    if (catalogPlugins.isEmpty) {
      if (_s._forjaLivePluginLoads.isNotEmpty) {
        setState(() => _s._forjaLivePluginLoads = {});
      }
      return;
    }
    final next = <String, _ForjaLivePluginLoad>{};
    for (final catalog in catalogPlugins) {
      final filterId = EngineService.catalogFilterId(catalog);
      final existing = _s._forjaLivePluginLoads[filterId];
      next[filterId] = existing ??
          _ForjaLivePluginLoad(
            pluginId: filterId,
            label: catalog.name,
          );
    }
    if (_forjaLivePluginLoadsEqual(next, _s._forjaLivePluginLoads)) return;
    setState(() => _s._forjaLivePluginLoads = next);
    _ensureForjaLivePluginFilterValid();
    (this as _LiveMatchesData)._scheduleRestoreLiveMatchesTvFocus();
  }

  bool _forjaLivePluginLoadsEqual(
    Map<String, _ForjaLivePluginLoad> a,
    Map<String, _ForjaLivePluginLoad> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final other = b[e.key];
      if (other == null ||
          other.pluginId != e.value.pluginId ||
          other.label != e.value.label ||
          other.loading != e.value.loading ||
          other.attempted != e.value.attempted ||
          other.matchCount != e.value.matchCount ||
          other.error != e.value.error) {
        return false;
      }
    }
    return true;
  }

  List<EnginePlugin> _forjaLiveCatalogsToLoad(
    List<EnginePlugin> catalogPlugins,
    String filter,
  ) {
    final out = <EnginePlugin>[];
    for (final catalog in catalogPlugins) {
      final filterId = EngineService.catalogFilterId(catalog);
      final load = _s._forjaLivePluginLoads[filterId];
      if (load == null || load.loading || load.attempted) continue;
      if (filter == 'all' || filterId == filter) {
        out.add(catalog);
      }
    }
    return out;
  }

  Future<void> _loadOneForjaLiveCatalog({
    required EnginePlugin catalog,
    required int gen,
  }) async {
    final filterId = EngineService.catalogFilterId(catalog);
    bool genAlive() => mounted && gen == _s._forjaLiveLoadGen;

    final load = _s._forjaLivePluginLoads[filterId];
    if (load == null || load.loading || load.attempted) return;

    setState(() {
      _s._forjaLivePluginLoads[filterId] =
          _s._forjaLivePluginLoads[filterId]!.copyWith(loading: true);
    });

    try {
      final extraConfig = await _liveCatalogExtraConfig(catalog);
      if (!genAlive()) return;
      final rows = await EngineService.instance.runLiveCatalog(
        catalogPlugin: catalog,
        extraConfig: extraConfig,
      );
      // Always cache on success — chip filter must not discard finished rows.
      if (!genAlive()) return;
      if (LiveMatchesEngine.cachedIsNativeUnlock(catalog.id, 'ppv') ||
          LiveMatchesEngine.cachedIsNativeUnlock(filterId, 'ppv')) {
        await LiveMatchesEngine.ppvWebOrigin();
        final streams = rows
            .where((row) =>
                _forjaLiveCatalogRowInHorizon(row, _s._scheduleHorizon))
            .map(_damiTvFromPpvCatalogRow)
            .where((s) => s.id.isNotEmpty && s.name.isNotEmpty)
            .toList();
        setState(() {
          _s._damiTvStreams = [..._s._damiTvStreams, ...streams];
          _s._forjaLivePluginLoads[filterId] =
              _s._forjaLivePluginLoads[filterId]!.copyWith(
            loading: false,
            attempted: true,
            matchCount: streams.length,
            error: null,
          );
        });
        _rebuildSportTabsFromCurrentMatches();
        return;
      }

      final Iterable<Map<String, dynamic>> visibleRows = rows.where(
        (row) => _forjaLiveCatalogRowInHorizon(row, _s._scheduleHorizon),
      );
      final matchRows = visibleRows
          .map(_forjaLiveRowToMatch)
          .where((m) => m.id.isNotEmpty && m.title.isNotEmpty);
      final uncapped = LiveMatchesEngine.cachedIsNativeUnlock(
            catalog.id,
            'streamed',
          ) ||
          LiveMatchesEngine.cachedIsNativeUnlock(filterId, 'streamed');
      final matches = uncapped
          ? matchRows.toList()
          : matchRows.take(_kForjaLiveCatalogMaxPerPlugin).toList();
      setState(() {
        _s._streamedMatches = _sortStreamedLiveFirst([
          ..._s._streamedMatches,
          ...matches,
        ]);
        if (catalog.id == 'catalog-espn' ||
            filterId == 'catalog-espn') {
          _syncEspnGamesFromStreamed();
        }
        _s._forjaLivePluginLoads[filterId] =
            _s._forjaLivePluginLoads[filterId]!.copyWith(
          loading: false,
          attempted: true,
          matchCount: matches.length,
          error: null,
        );
      });
      _rebuildSportTabsFromCurrentMatches();
    } catch (e) {
      debugPrint('[LiveMatches] Forja Live ${catalog.id}: $e');
      if (!genAlive()) return;
      setState(() {
        _s._forjaLivePluginLoads[filterId] =
            _s._forjaLivePluginLoads[filterId]!.copyWith(
          loading: false,
          attempted: true,
          matchCount: 0,
          error: '$e',
        );
      });
      (this as _LiveMatchesData)
          ._scheduleRestoreRefreshFocus(clearWhenSettled: true);
    }
  }

  Future<void> _loadForjaLiveCatalogLazy() async {
    final gen = _s._forjaLiveLoadGen;
    _s._catalogFetchedHorizon = _s._scheduleHorizon;
    await LiveMatchesEngine.warmPluginMeta();
    await EngineService.instance.ensureOfficialInstalled();
    final catalogPlugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    if (!mounted || gen != _s._forjaLiveLoadGen) return;

    _ensureForjaLivePluginLoadsRegistered(catalogPlugins);
    if (!mounted || gen != _s._forjaLiveLoadGen) return;

    if (catalogPlugins.isEmpty) {
      await _applyEspnScheduleMerge();
      return;
    }

    final filter = _s._forjaLivePluginFilter;
    final toLoad = _forjaLiveCatalogsToLoad(catalogPlugins, filter);
    if (toLoad.isEmpty) {
      await _applyEspnScheduleMerge();
      return;
    }

    // Finish every catalog in [toLoad] even if the chip filter changes mid-loop
    // so each scrape is cached once (`attempted`) for the session.
    for (final catalog in toLoad) {
      if (!mounted || gen != _s._forjaLiveLoadGen) return;
      await _loadOneForjaLiveCatalog(catalog: catalog, gen: gen);
    }

    if (!mounted || gen != _s._forjaLiveLoadGen) return;
    _ensureForjaLivePluginFilterValid();
    await _applyEspnScheduleMerge();
  }

  void _deferTabControllerDispose(TabController? ctrl) {
    if (ctrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  }

  bool _sportCategoryIdsEqual(List<_Sport> a, List<_Sport> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  List<_Sport> _sportCategoriesFromCurrentMatches() {
    final seen = <String>{};
    final cats = <_Sport>[];
    final applyWindow = (this as _LiveMatchesData)._applyTimeWindowFilter;

    void addCat(String raw) {
      final id = _normalizeSportId(raw);
      if (id.isEmpty || !seen.add(id)) return;
      cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
    }

    if (_s._server == _LiveMatchesServer.all ||
        _s._server == _LiveMatchesServer.forjaLive ||
        _s._server == _LiveMatchesServer.iptvSports) {
      for (final s in _s._damiTvStreams) {
        if (applyWindow &&
            !_damiTvInScheduleFilter(
              s,
              status: _s._scheduleStatus,
              horizon: _s._scheduleHorizon,
            )) {
          continue;
        }
        if (_is247Item(category: s.categoryName, isAlwaysOn: s.isAlwaysOn)) {
          addCat('24/7');
        } else {
          addCat(s.categoryName);
        }
      }
    }

    for (final m in _s._streamedMatches) {
      if (applyWindow &&
          !_streamedMatchInScheduleFilter(
            m,
            status: _s._scheduleStatus,
            horizon: _s._scheduleHorizon,
          )) {
        continue;
      }
      if (_is247Item(category: m.category, isAlwaysOn: m.isAlwaysOn)) {
        addCat('24/7');
      } else {
        addCat(m.category);
      }
    }

    cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return cats;
  }

  void _syncNewTabControllerIndex(
    TabController ctrl,
    List<_Sport> cats,
    String filter,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _s._tabController != ctrl) return;
      try {
        if (filter == 'all') {
          if (ctrl.index != 0) ctrl.index = 0;
        } else {
          final idx = cats.indexWhere((c) => c.id == filter);
          if (idx >= 0 && ctrl.index != idx + 1) ctrl.index = idx + 1;
        }
      } catch (_) {}
    });
  }

  void _rebuildSportTabsFromCurrentMatches() {
    if (!mounted) return;
    final cats = _sportCategoriesFromCurrentMatches();
    if (cats.isEmpty) {
      (this as _LiveMatchesData)
        .._scheduleRestoreRefreshFocus(clearWhenSettled: true)
        .._scheduleRestoreLiveMatchesTvFocus();
      return;
    }

    if (_sportCategoryIdsEqual(cats, _s._sports) &&
        _s._tabController != null &&
        _s._tabController!.length == cats.length + 1) {
      (this as _LiveMatchesData)
        .._scheduleRestoreRefreshFocus(clearWhenSettled: true)
        .._scheduleRestoreLiveMatchesTvFocus();
      return;
    }

    _releaseLiveMatchesItemFocusIfHeld();

    final oldCtrl = _s._tabController;
    final prevFilter = _s._sportFilter;
    final newCtrl = TabController(length: cats.length + 1, vsync: _s);
    newCtrl.addListener(() {
      if (!newCtrl.indexIsChanging) {
        final idx = newCtrl.index;
        (this as _LiveMatchesData)._setSportFilter(
          idx == 0 ? 'all' : cats[idx - 1].id,
        );
      }
    });

    var nextFilter = prevFilter;
    if (nextFilter != 'all' && !cats.any((c) => c.id == nextFilter)) {
      nextFilter = 'all';
    }

    setState(() {
      _s._tabController = newCtrl;
      _s._sports = cats;
      _s._sportFilter = nextFilter;
    });
    _deferTabControllerDispose(oldCtrl);
    _syncNewTabControllerIndex(newCtrl, cats, nextFilter);
    (this as _LiveMatchesData)
      .._scheduleRestoreRefreshFocus(clearWhenSettled: true)
      .._scheduleRestoreLiveMatchesTvFocus();
  }
}
