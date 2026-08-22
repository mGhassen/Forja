part of 'live_matches_screen.dart';

class _ForjaLivePluginLoad {
  const _ForjaLivePluginLoad({
    required this.pluginId,
    required this.label,
    this.loading = false,
    this.matchCount = 0,
    this.error,
  });

  final String pluginId;
  final String label;
  final bool loading;
  final int matchCount;
  final String? error;

  _ForjaLivePluginLoad copyWith({
    bool? loading,
    int? matchCount,
    String? error,
  }) => _ForjaLivePluginLoad(
    pluginId: pluginId,
    label: label,
    loading: loading ?? this.loading,
    matchCount: matchCount ?? this.matchCount,
    error: error,
  );
}

mixin _LiveMatchesForjaLive
    on ConsumerState<LiveMatchesScreen>, _LiveMatchesData {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  bool get _usesForjaLiveLazyCatalog =>
      _s._server == _LiveMatchesServer.all ||
      _s._server == _LiveMatchesServer.forjaLive;

  bool get _showForjaLiveCatalogChrome =>
      _usesForjaLiveLazyCatalog && _s._forjaLivePluginLoads.isNotEmpty;

  bool get _forjaLiveAnyLoading =>
      _s._forjaLivePluginLoads.values.any((e) => e.loading);

  bool _forjaLiveMatchPlayable(_StreamedMatch match) {
    if (_forjaLiveAnyLoading) return false;
    return _streamedMatchesForEvent(match, _s._streamedMatches).any(
      (m) =>
          m.sources.isNotEmpty ||
          m.inlineStreams.isNotEmpty ||
          m.isStremio ||
          m.sportMatchGame != null,
    );
  }

  List<_StreamedMatch> get _displayStreamedMatches {
    var list = (this as _LiveMatchesData)._filteredStreamed;
    if (_s._server == _LiveMatchesServer.forjaLive) {
      list = list.where((m) => !m.isIptvSports).toList();
    }
    if (_s._server == _LiveMatchesServer.forjaLive &&
        _s._forjaLivePluginFilter != 'all') {
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

  void _resetForjaLiveCatalogState() {
    EngineService.instance.cancelLiveCatalog();
    _s._forjaLiveLoadGen++;
    _s._forjaLivePluginLoads = {};
    _s._streamedMatches = _s._streamedMatches
        .where((m) => !m.isForjaLive)
        .toList();
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

  void _onEngineCatalogSettingsChanged() {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!(this as ShellTabRefresh<LiveMatchesScreen>).shellTabVisible) return;
    _resetForjaLiveCatalogState();
    _kickForjaLiveLazyCatalog();
  }

  Future<bool> _isEspnCatalogEnabled() async {
    await EngineService.instance.ensureBundledInstalled();
    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (p.id == 'catalog-espn') return p.enabled;
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

  /// Enrich other catalog rows with ESPN teams; ESPN catalog rows load separately.
  Future<void> _applyEspnScheduleMerge() async {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!mounted) return;
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

  Future<void> _loadForjaLiveCatalogLazy() async {
    final gen = _s._forjaLiveLoadGen;
    await EngineService.instance.ensureBundledInstalled();
    final catalogPlugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    if (!mounted || gen != _s._forjaLiveLoadGen) return;

    if (catalogPlugins.isEmpty) {
      if (_s._server == _LiveMatchesServer.forjaLive) {
        setState(() => _s._forjaLivePluginLoads = {});
      }
      await _applyEspnScheduleMerge();
      return;
    }

    setState(() {
      _s._forjaLivePluginLoads = {
        for (final catalog in catalogPlugins)
          EngineService.catalogFilterId(catalog): _ForjaLivePluginLoad(
            pluginId: EngineService.catalogFilterId(catalog),
            label: catalog.name,
            loading: true,
          ),
      };
    });
    _ensureForjaLivePluginFilterValid();

    for (final catalog in catalogPlugins) {
      if (!mounted || gen != _s._forjaLiveLoadGen) return;
      final filterId = EngineService.catalogFilterId(catalog);
      try {
        final extraConfig = await _liveCatalogExtraConfig(catalog);
        if (!mounted || gen != _s._forjaLiveLoadGen) return;
        final rows = await EngineService.instance.runLiveCatalog(
          catalogPlugin: catalog,
          extraConfig: extraConfig,
        );
        final matches = rows
            .where(_forjaLiveCatalogRowVisible)
            .map(_forjaLiveRowToMatch)
            .where((m) => m.id.isNotEmpty && m.title.isNotEmpty)
            .take(_kForjaLiveCatalogMaxPerPlugin)
            .toList();
        if (!mounted || gen != _s._forjaLiveLoadGen) return;
        setState(() {
          _s._streamedMatches = _sortStreamedLiveFirst([
            ..._s._streamedMatches,
            ...matches,
          ]);
          if (catalog.id == 'catalog-espn') {
            _syncEspnGamesFromStreamed();
          }
          _s._forjaLivePluginLoads[filterId] =
              _s._forjaLivePluginLoads[filterId]!.copyWith(
            loading: false,
            matchCount: matches.length,
            error: null,
          );
        });
      } catch (e) {
        debugPrint('[LiveMatches] Forja Live ${catalog.id}: $e');
        if (!mounted || gen != _s._forjaLiveLoadGen) return;
        setState(() {
          _s._forjaLivePluginLoads[filterId] =
              _s._forjaLivePluginLoads[filterId]!.copyWith(
            loading: false,
            matchCount: 0,
            error: '$e',
          );
        });
      }
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

    void addCat(String raw) {
      final id = _normalizeSportId(raw);
      if (id.isEmpty || !seen.add(id)) return;
      cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
    }

    if (_s._server == _LiveMatchesServer.all ||
        _s._server == _LiveMatchesServer.forjaLive ||
        _s._server == _LiveMatchesServer.iptvSports) {
      for (final s in _s._damiTvStreams) {
        if (_is247Item(category: s.categoryName, isAlwaysOn: s.isAlwaysOn)) {
          addCat('24/7');
        } else {
          addCat(s.categoryName);
        }
      }
    }

    for (final m in _s._streamedMatches) {
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
    if (cats.isEmpty) return;

    if (_sportCategoryIdsEqual(cats, _s._sports) &&
        _s._tabController != null &&
        _s._tabController!.length == cats.length + 1) {
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
  }
}
