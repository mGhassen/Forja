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

mixin _LiveMatchesForjaLive on ConsumerState<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  bool get _usesForjaLiveLazyCatalog =>
      _s._server == _LiveMatchesServer.all ||
      _s._server == _LiveMatchesServer.forjaLive;

  bool get _showForjaLiveCatalogChrome =>
      _usesForjaLiveLazyCatalog && _s._forjaLivePluginLoads.isNotEmpty;

  bool get _forjaLiveAnyLoading =>
      _s._forjaLivePluginLoads.values.any((e) => e.loading);

  List<_StreamedMatch> get _displayStreamedMatches {
    var list = (this as _LiveMatchesData)._filteredStreamed;
    if (_s._server == _LiveMatchesServer.forjaLive &&
        _s._forjaLivePluginFilter != 'all') {
      list = list
          .where((m) => m.livePluginId == _s._forjaLivePluginFilter)
          .toList();
    }
    return list;
  }

  void _resetForjaLiveCatalogState() {
    _s._forjaLiveLoadGen++;
    _s._forjaLivePluginFilter = 'all';
    _s._forjaLivePluginLoads = {};
    _s._streamedMatches = _s._streamedMatches
        .where((m) => !m.isForjaLive)
        .toList();
  }

  void _kickForjaLiveLazyCatalog() {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!(this as ShellTabRefresh<LiveMatchesScreen>).shellTabVisible) return;
    if (!_s._serverHydrated) return;
    unawaited(_loadForjaLiveCatalogLazy());
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

    for (final catalog in catalogPlugins) {
      if (!mounted || gen != _s._forjaLiveLoadGen) return;
      final filterId = EngineService.catalogFilterId(catalog);
      try {
        final extra = await _forjaLiveCatalogExtraConfig(catalog);
        final rows = await EngineService.instance.runLiveCatalog(
          catalogPlugin: catalog,
          extraConfig: extra,
          timeout: LiveMatchesEngine.catalogPluginTimeout,
        );
        final matches = rows
            .map(_forjaLiveRowToMatch)
            .where((m) => m.id.isNotEmpty && m.title.isNotEmpty)
            .toList();
        if (!mounted || gen != _s._forjaLiveLoadGen) return;
        setState(() {
          _s._streamedMatches = _sortStreamedLiveFirst([
            ..._s._streamedMatches,
            ...matches,
          ]);
          _s._forjaLivePluginLoads[filterId] =
              _s._forjaLivePluginLoads[filterId]!.copyWith(
            loading: false,
            matchCount: matches.length,
            error: null,
          );
        });
        _rebuildSportTabsFromCurrentMatches();
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
  }

  Future<Map<String, dynamic>> _forjaLiveCatalogExtraConfig(
    EnginePlugin catalog,
  ) async {
    if (catalog.id != 'catalog-espn') return const {};
    final config = await LiveMatchesIptvSportsConfig.load();
    final leagues = config.leagues.isEmpty
        ? LiveMatchesIptvSportsConfig.allLeagues
        : config.leagues;
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return {'leagues': leagues, 'date': date};
  }

  void _rebuildSportTabsFromCurrentMatches() {
    if (!mounted) return;
    final seen = <String>{};
    final cats = <_Sport>[];

    void addCat(String raw) {
      final id = _normalizeSportId(raw);
      if (id.isEmpty || !seen.add(id)) return;
      cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
    }

    if (_s._server == _LiveMatchesServer.all ||
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
    if (cats.isEmpty) return;

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
    oldCtrl?.dispose();
    if (nextFilter == 'all') {
      newCtrl.index = 0;
    } else {
      final idx = cats.indexWhere((c) => c.id == nextFilter);
      if (idx >= 0) newCtrl.index = idx + 1;
    }
  }
}
