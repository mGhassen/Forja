part of '../live_sports_hub_page.dart';

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
    on ConsumerState<LiveSportsHubPage>, _LiveMatchesData {
  @override
  LiveSportsHubPageState get _s => this as LiveSportsHubPageState;

  bool get _usesForjaLiveLazyCatalog => true;

  bool get _showForjaLiveCatalogChrome =>
      _usesForjaLiveLazyCatalog &&
      _s._showCatalogTopBar &&
      _s._forjaLivePluginLoads.isNotEmpty;

  bool _catalogFilterMatches(String filterId, String filter) {
    if (filter == 'all' || filter.isEmpty) return true;
    if (_isStremioCatalogFilter(filter) || _isStremioCatalogFilter(filterId)) {
      return filterId == filter ||
          _stremioBaseUrlFromCatalogFilter(filterId) ==
              _stremioBaseUrlFromCatalogFilter(filter);
    }
    return EngineService.normalizeLiveSportPluginId(filterId) ==
        EngineService.normalizeLiveSportPluginId(filter);
  }

  _ForjaLivePluginLoad? _forjaLivePluginLoadForFilter(String filter) {
    if (filter == 'all' || filter.isEmpty) return null;
    final direct = _s._forjaLivePluginLoads[filter];
    if (direct != null) return direct;
    if (_isStremioCatalogFilter(filter)) {
      final base = _stremioBaseUrlFromCatalogFilter(filter);
      if (base == null) return null;
      for (final entry in _s._forjaLivePluginLoads.entries) {
        if (_stremioBaseUrlFromCatalogFilter(entry.key) == base) {
          return entry.value;
        }
      }
      return null;
    }
    final norm = EngineService.normalizeLiveSportPluginId(filter);
    for (final entry in _s._forjaLivePluginLoads.entries) {
      if (_isStremioCatalogFilter(entry.key)) continue;
      if (EngineService.normalizeLiveSportPluginId(entry.key) == norm) {
        return entry.value;
      }
    }
    return null;
  }

  String? _canonicalForjaLivePluginFilterKey(String filter) {
    if (filter == 'all' || filter.isEmpty) return filter;
    if (_s._forjaLivePluginLoads.containsKey(filter)) return filter;
    if (_isStremioCatalogFilter(filter)) {
      final base = _stremioBaseUrlFromCatalogFilter(filter);
      if (base == null) return null;
      for (final key in _s._forjaLivePluginLoads.keys) {
        if (_stremioBaseUrlFromCatalogFilter(key) == base) return key;
      }
      return null;
    }
    final norm = EngineService.normalizeLiveSportPluginId(filter);
    for (final key in _s._forjaLivePluginLoads.keys) {
      if (_isStremioCatalogFilter(key)) continue;
      if (EngineService.normalizeLiveSportPluginId(key) == norm) return key;
    }
    return null;
  }

  Iterable<_ForjaLivePluginLoad> get _gridScopedPluginLoads {
    final filter = _activeForjaLiveCatalogFilter;
    if (filter.isEmpty) return const [];
    return _s._forjaLivePluginLoads.values.where(
      (e) => _catalogFilterMatches(e.pluginId, filter),
    );
  }

  /// Selected catalog only — no merged "All" grid.
  String get _activeForjaLiveCatalogFilter {
    final raw = _s._forjaLivePluginFilter;
    if (raw.isEmpty || raw == 'all') {
      return _defaultForjaLiveCatalogFilterKey() ?? '';
    }
    return _canonicalForjaLivePluginFilterKey(raw) ?? raw;
  }

  String? _defaultForjaLiveCatalogFilterKey() {
    if (_s._forjaLivePluginLoads.isEmpty) return null;
    final sorted = _s._forjaLivePluginLoads.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return sorted.first.pluginId;
  }

  String? _defaultForjaLiveCatalogLabel() {
    final key = _defaultForjaLiveCatalogFilterKey();
    if (key == null) return null;
    return _s._forjaLivePluginLoads[key]?.label ??
        _liveForjaPluginDisplayName(key);
  }

  bool get _forjaLiveAnyLoading => _gridScopedPluginLoads.any((e) => e.loading);

  bool get _forjaLiveCatalogBusy =>
      _usesForjaLiveLazyCatalog &&
      (_s._forjaLiveCatalogHydrating || _forjaLiveAnyLoading);

  /// Full-screen spinner only before the first scoped catalog finishes.
  bool get _forjaLiveCatalogInitialBusy =>
      _usesForjaLiveLazyCatalog &&
      _s._forjaLiveCatalogHydrating &&
      !_gridScopedPluginLoads.any((e) => e.attempted);

  void _setForjaLiveCatalogHydrating(bool value) {
    if (_s._forjaLiveCatalogHydrating == value) return;
    setState(() => _s._forjaLiveCatalogHydrating = value);
  }

  void _beginForjaLiveCatalogHydration() {
    if (!_usesForjaLiveLazyCatalog) return;
    _setForjaLiveCatalogHydrating(true);
  }

  /// Drop the full-screen hydrate once scoped rows exist or any catalog returned.
  ///
  /// While plugin rows are still empty (listing catalogs), leave hydrating alone —
  /// clearing it here flashes "No streams available" before discovery finishes.
  void _syncCatalogHydratingState() {
    if (!_usesForjaLiveLazyCatalog) {
      _setForjaLiveCatalogHydrating(false);
      return;
    }
    final scoped = _gridScopedPluginLoads.toList();
    if (scoped.isEmpty) return;
    final sources = _catalogFilteredGridSources();
    final hasEntries =
        sources.streamed.isNotEmpty || sources.iframeCatalog.isNotEmpty;
    final anyAttempted = scoped.any((e) => e.attempted);
    if (hasEntries || anyAttempted) {
      _setForjaLiveCatalogHydrating(false);
      return;
    }
    // First scoped catalog not finished — keep spinner even if `loading` lags
    // a frame behind registration / dispatch.
    _setForjaLiveCatalogHydrating(true);
  }

  void _cancelOutOfScopeCatalogLoads(String filter) {
    if (filter == 'all' || filter.isEmpty) return;
    for (final entry in _s._forjaLivePluginLoads.entries.toList()) {
      if (_catalogFilterMatches(entry.key, filter)) continue;
      final load = entry.value;
      if (!load.loading) continue;
      _s._forjaLivePluginLoads[entry.key] = load.copyWith(loading: false);
    }
  }

  void _invalidateLiveMatchesGridCache() {
    _s._liveMatchesGridCacheRevision++;
    _s._cachedLiveMatchesGridEntries = null;
  }

  void _maybeRebuildSportTabsFromCurrentMatches() {
    _rebuildSportTabsFromCurrentMatches();
  }

  bool _forjaLiveMatchPlayable(_StreamedMatch match) {
    return !_forjaLiveAnyLoading && match.isLive;
  }

  List<_StreamedMatch> _catalogScopedStreamedMatches() {
    final raw =
        (this as _LiveMatchesData)._streamedMatchesSportAndTimeFiltered();
    if (!_showForjaLiveCatalogChrome) {
      return _mergeStreamedCatalogRows(_sortStreamedLiveFirst(raw));
    }
    final filter = _activeForjaLiveCatalogFilter;
    if (filter.isEmpty) return const [];
    return _streamedMatchesForCatalogGrid(raw, filter);
  }

  List<_StreamedMatch> get _displayStreamedMatches {
    var list = _catalogScopedStreamedMatches();
    list = list.where((m) => !m.isIptvSports).toList();
    return list;
  }

  ({List<_IframeCatalogStream> iframeCatalog, List<_StreamedMatch> streamed})
  _catalogFilteredGridSources() {
    if (!_showForjaLiveCatalogChrome) {
      return (
        iframeCatalog: (this as _LiveMatchesData)._filteredIframeCatalog,
        streamed: (this as _LiveMatchesData)._filteredStreamed,
      );
    }
    final filter = _activeForjaLiveCatalogFilter;
    if (filter.isEmpty) {
      return (iframeCatalog: const [], streamed: const []);
    }
    if (!_isStremioCatalogFilter(filter) &&
        LiveMatchesEngine.cachedIsIframeCatalog(filter)) {
      return (
        iframeCatalog: (this as _LiveMatchesData)._filteredIframeCatalog,
        streamed: [],
      );
    }
    return (iframeCatalog: [], streamed: _catalogScopedStreamedMatches());
  }

  /// Same catalog scope as the grid, but without the active sport-chip filter.
  ({List<_IframeCatalogStream> iframeCatalog, List<_StreamedMatch> streamed})
  _catalogSourcesForSportTabs() {
    if (!_showForjaLiveCatalogChrome) {
      return (iframeCatalog: _s._iframeCatalogStreams, streamed: _s._streamedMatches);
    }
    final filter = _activeForjaLiveCatalogFilter;
    if (filter.isEmpty) {
      return (iframeCatalog: const [], streamed: const []);
    }
    if (!_isStremioCatalogFilter(filter) &&
        LiveMatchesEngine.cachedIsIframeCatalog(filter)) {
      return (iframeCatalog: _s._iframeCatalogStreams, streamed: []);
    }
    return (
      iframeCatalog: [],
      streamed: _streamedMatchesForCatalogGrid(_s._streamedMatches, filter),
    );
  }

  void _resetForjaLiveCatalogState({
    bool clearMatches = true,
    String? catalogFilter,
  }) {
    EngineService.instance.cancelLiveCatalog();
    _s._forjaLiveLoadGen++;
    if (catalogFilter == null || catalogFilter == 'all') {
      _s._forjaLivePluginLoads = {};
      if (!clearMatches) return;
      _s._iframeCatalogStreams = [];
      _s._streamedMatches = _s._streamedMatches
          .where((m) => !m.isForjaLive && !m.isStremio)
          .toList();
      _s._eventStreamViewerTotals.clear();
      return;
    }
    if (_isStremioCatalogFilter(catalogFilter)) {
      final base = _stremioBaseUrlFromCatalogFilter(catalogFilter);
      _s._forjaLivePluginLoads.removeWhere(
        (id, _) => _catalogFilterMatches(id, catalogFilter),
      );
      if (!clearMatches || base == null) return;
      _s._streamedMatches = _s._streamedMatches
          .where(
            (m) =>
                !m.isStremio ||
                SettingsService.normalizeStremioAddonBaseUrl(m.stremioBaseUrl) !=
                    base,
          )
          .toList();
      return;
    }
    final norm = EngineService.normalizeLiveSportPluginId(catalogFilter);
    _s._forjaLivePluginLoads.removeWhere(
      (id, _) => _catalogFilterMatches(id, catalogFilter),
    );
    if (!clearMatches) return;
    _s._iframeCatalogStreams = _s._iframeCatalogStreams
        .where(
          (s) => !LiveMatchesEngine.cachedIsIframeCatalog(norm),
        )
        .toList();
    // Catalog chip filters the schedule grid only — keep other catalog rows
    // cached for cross-provider stream resolve on match open.
  }

  Future<void> _restoreForjaLiveCatalogFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(
      LiveSportsHubPageState._forjaLiveCatalogFilterPreferenceKey,
    );
    if (saved == null || saved.isEmpty || saved == 'all') return;
    if (!mounted) return;
    setState(() => _s._forjaLivePluginFilter = saved);
  }

  Future<void> _persistForjaLiveCatalogFilterPreference(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      LiveSportsHubPageState._forjaLiveCatalogFilterPreferenceKey,
      filter,
    );
  }

  void _setForjaLivePluginFilter(String filter) {
    if (_s._forjaLivePluginFilter == filter) return;
    EngineService.instance.cancelLiveCatalog();
    _s._forjaLiveLoadGen++;
    setState(() {
      _invalidateLiveMatchesGridCache();
      _s._forjaLivePluginFilter = filter;
      _cancelOutOfScopeCatalogLoads(filter);
      _syncCatalogHydratingState();
    });
    unawaited(_persistForjaLiveCatalogFilterPreference(filter));
    _rebuildSportTabsFromCurrentMatches();
    _kickForjaLiveLazyCatalog(replace: true);
  }

  Future<void> _restoreTimeWindowPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LiveSportsHubPageState._schedulePreferenceKey) ??
        prefs.getString(LiveSportsHubPageState._timeWindowPreferenceKeyLegacy);
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
      LiveSportsHubPageState._schedulePreferenceKey,
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
    _resetForjaLiveCatalogState(clearMatches: false);
    _s._catalogFetchedHorizon = horizon;
    _kickForjaLiveLazyCatalog(replace: true);
  }

  /// Rows we already have for this fixture (opened card + pool) — no catalog HTTP.
  List<_StreamedMatch> _knownProviderEventMatches(_StreamedMatch match) {
    return _providerResolveTargets(match, _s._streamedMatches);
  }

  /// Providers must never follow the Catalog chip — load every stream-capable
  /// catalog into the pool (grid display stays chip-scoped).
  Future<void> _ensureAllCatalogsForProviders({
    required bool Function() isStale,
  }) async {
    if (!_usesForjaLiveLazyCatalog) return;
    await LiveMatchesEngine.warmPluginMeta();
    if (isStale() || !mounted) return;

    final catalogPlugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    if (isStale() || !mounted) return;

    _ensureForjaLivePluginLoadsRegistered(catalogPlugins);
    if (isStale() || !mounted) return;

    final toStart = <EnginePlugin>[];
    for (final catalog in catalogPlugins) {
      // ESPN enrich / broadcast-hint packs have no Providers stream refs.
      if (!LiveMatchesEngine.isProviderStreamCatalog(catalog)) continue;
      final filterId = EngineService.catalogFilterId(catalog);
      final load = _s._forjaLivePluginLoads[filterId];
      if (load == null || load.attempted || load.loading) continue;
      toStart.add(catalog);
    }

    debugPrint(
      '[LiveMatches] Providers pool: '
      '${toStart.length} catalogs to load '
      '(${[
        for (final c in catalogPlugins)
          if (LiveMatchesEngine.isProviderStreamCatalog(c))
            '${EngineService.catalogFilterId(c)}:'
                '${_s._forjaLivePluginLoads[EngineService.catalogFilterId(c)]?.attempted == true ? 'ready' : (_s._forjaLivePluginLoads[EngineService.catalogFilterId(c)]?.loading == true ? 'loading' : 'pending')}',
      ].join(', ')})',
    );

    final gen = _s._forjaLiveLoadGen;
    if (toStart.isNotEmpty) {
      setState(() {
        for (final catalog in toStart) {
          final filterId = EngineService.catalogFilterId(catalog);
          final row = _s._forjaLivePluginLoads[filterId];
          if (row == null || row.loading || row.attempted) continue;
          _s._forjaLivePluginLoads[filterId] = row.copyWith(loading: true);
        }
      });
      await Future.wait([
        for (final catalog in toStart)
          _loadOneForjaLiveCatalog(catalog: catalog, gen: gen),
      ]);
    }

    // Grid may already be loading other packs — wait until stream catalogs settle.
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!isStale() && mounted && DateTime.now().isBefore(deadline)) {
      final stillLoading = catalogPlugins.any((catalog) {
        if (!LiveMatchesEngine.isProviderStreamCatalog(catalog)) return false;
        final load =
            _s._forjaLivePluginLoads[EngineService.catalogFilterId(catalog)];
        return load != null && load.loading;
      });
      if (!stillLoading) break;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  void _ensureForjaLivePluginFilterValid() {
    if (_s._forjaLivePluginLoads.isEmpty) return;
    final defaultKey = _defaultForjaLiveCatalogFilterKey();
    if (defaultKey == null) return;

    final raw = _s._forjaLivePluginFilter;
    if (raw.isEmpty || raw == 'all') {
      if (raw != defaultKey) {
        setState(() => _s._forjaLivePluginFilter = defaultKey);
        unawaited(_persistForjaLiveCatalogFilterPreference(defaultKey));
      }
      return;
    }

    final canonical = _canonicalForjaLivePluginFilterKey(raw);
    if (canonical == null) {
      if (_s._forjaLivePluginFilter != defaultKey) {
        _setForjaLivePluginFilter(defaultKey);
      }
      return;
    }
    if (canonical != _s._forjaLivePluginFilter) {
      setState(() => _s._forjaLivePluginFilter = canonical);
      unawaited(_persistForjaLiveCatalogFilterPreference(canonical));
    }
  }

  void _kickForjaLiveLazyCatalog({bool replace = false}) {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!(this as ShellTabRefresh<LiveSportsHubPage>).shellTabVisible) return;
    if (!_s._browseHydrated) return;
    if (_s._forjaLiveGridCatalogInflight != null && !replace) return;
    if (replace) {
      EngineService.instance.cancelLiveCatalog();
      _s._forjaLiveLoadGen++;
    }
    _beginForjaLiveCatalogHydration();
    final serial = ++_s._forjaLiveGridCatalogInflightSerial;
    final future = _loadForjaLiveCatalogLazy();
    _s._forjaLiveGridCatalogInflight = future;
    unawaited(
      future.whenComplete(() {
        if (_s._forjaLiveGridCatalogInflightSerial != serial) return;
        _s._forjaLiveGridCatalogInflight = null;
      }),
    );
  }

  void _clearPluginScheduleCaches() {
    LiveMatchesEngine.invalidateDerivedCaches();
    IptvSportsMatchService.invalidateBroadcastCaches();
  }

  void _applyEngineCatalogSettingsChange({required bool reloadNow}) {
    if (!_usesForjaLiveLazyCatalog) return;
    _clearPluginScheduleCaches();
    _resetForjaLiveCatalogState(clearMatches: true);
    if (!reloadNow) {
      _s._forjaLiveCatalogSettingsDirty = true;
      if (mounted) setState(() {});
      return;
    }
    _s._forjaLiveCatalogSettingsDirty = false;
    if (mounted) setState(() {});
    _kickForjaLiveLazyCatalog();
  }

  Future<bool> _isScheduleEnrichCatalogEnabled() async {
    final catalogs =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    return catalogs.any(LiveMatchesEngine.isScheduleEnrichCatalogPlugin);
  }

  void _syncScheduleEnrichGamesFromMatches() {
    _s._espnGames = [
      for (final m in _s._streamedMatches)
        if (m.sportMatchGame != null &&
            LiveMatchesEngine.cachedIsScheduleEnrichCatalog(m.livePluginId))
          Map<String, dynamic>.from(m.sportMatchGame!),
    ];
  }

  bool _shouldRunScheduleEnrichMerge() {
    final filter = _activeForjaLiveCatalogFilter;
    if (filter.isEmpty || _isStremioCatalogFilter(filter)) return false;
    return LiveMatchesEngine.cachedIsScheduleEnrichCatalog(filter);
  }

  /// Enrich other catalog rows with full-day scoreboard teams.
  Future<void> _applyScheduleEnrichMerge() async {
    if (!_usesForjaLiveLazyCatalog) return;
    if (!mounted) return;
    if (!_shouldRunScheduleEnrichMerge()) return;
    if (_forjaLiveAnyLoading) {
      return;
    }
    if (!await _isScheduleEnrichCatalogEnabled()) return;

    var enrichGames = _s._espnGames;
    if (enrichGames.isEmpty) {
      enrichGames = await IptvSportsMatchService.fetchEspnGames();
    }
    if (!mounted) return;

    final base = _stripEspnMergedScheduleRows(_s._streamedMatches);
    final merged = IptvSportsMatchService.mergeWithEspn(
      base,
      enrichGames,
      appendUnmatched: false,
    );
    setState(() {
      _invalidateLiveMatchesGridCache();
      _s._streamedMatches = merged.streamed;
      _s._espnGames = merged.espnGames;
    });
    _maybeRebuildSportTabsFromCurrentMatches();
  }

  Future<Map<String, dynamic>> _liveCatalogExtraConfig(
    EnginePlugin catalog,
  ) async {
    final leaguesRaw = catalog.config['leagues'];
    if (leaguesRaw is! List || leaguesRaw.isEmpty) return const {};
    final sportsConfig = await LiveMatchesIptvSportsConfig.load();
    final leagues = sportsConfig.leagues.isEmpty
        ? [for (final lg in leaguesRaw) lg.toString()]
        : sportsConfig.leagues;
    return {'leagues': leagues, 'pluginId': catalog.id};
  }

  /// Keep engine catalog rows; preserve already-registered Stremio addon chips.
  void _ensureForjaLivePluginLoadsRegistered(List<EnginePlugin> catalogPlugins) {
    final next = <String, _ForjaLivePluginLoad>{};
    for (final entry in _s._forjaLivePluginLoads.entries) {
      if (_isStremioCatalogFilter(entry.key)) {
        next[entry.key] = entry.value;
      }
    }
    for (final catalog in catalogPlugins) {
      final filterId = EngineService.catalogFilterId(catalog);
      final existing = _s._forjaLivePluginLoads[filterId];
      next[filterId] = existing ??
          _ForjaLivePluginLoad(
            pluginId: filterId,
            label: catalog.name,
          );
    }
    if (catalogPlugins.isEmpty &&
        next.values.every((e) => _isStremioCatalogFilter(e.pluginId))) {
      // Engine packs gone — keep Stremio-only catalog list if any.
    }
    if (next.isEmpty) {
      if (_s._forjaLivePluginLoads.isNotEmpty) {
        setState(() => _s._forjaLivePluginLoads = {});
      }
      _ensureForjaLivePluginFilterValid();
      return;
    }
    if (_forjaLivePluginLoadsEqual(next, _s._forjaLivePluginLoads)) return;
    setState(() => _s._forjaLivePluginLoads = next);
    _ensureForjaLivePluginFilterValid();
    (this as _LiveMatchesData)._scheduleRestoreLiveMatchesTvFocus();
  }

  /// Add each live-targeted Stremio addon as a Catalog picker row.
  Future<void> _ensureStremioCatalogLoadsRegistered() async {
    if (!_usesForjaLiveLazyCatalog) return;
    List<Map<String, dynamic>> addons;
    try {
      addons = await StremioService().peekAddonsForFeature(
        StremioAddonFeatures.live,
      );
    } catch (e) {
      debugPrint('[LiveMatches] Stremio catalog list error: $e');
      return;
    }
    if (!mounted) return;

    final next = Map<String, _ForjaLivePluginLoad>.from(_s._forjaLivePluginLoads);
    next.removeWhere((key, _) => _isStremioCatalogFilter(key));

    for (final addon in addons) {
      final baseUrl = addon['baseUrl']?.toString() ?? '';
      if (baseUrl.trim().isEmpty) continue;
      final filterId = _stremioCatalogFilterId(baseUrl);
      final label = _stremioAddonNameFromInstall(addon);
      final existing = _s._forjaLivePluginLoads[filterId];
      next[filterId] = existing ??
          _ForjaLivePluginLoad(
            pluginId: filterId,
            label: label.isNotEmpty ? label : 'Stremio',
          );
    }

    if (_forjaLivePluginLoadsEqual(next, _s._forjaLivePluginLoads)) return;
    setState(() => _s._forjaLivePluginLoads = next);
    _ensureForjaLivePluginFilterValid();
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

  /// Only the selected catalog chip (engine packs — Stremio loads separately).
  List<EnginePlugin> _forjaLiveCatalogsToLoad(
    List<EnginePlugin> catalogPlugins,
  ) {
    final gridFilter = _activeForjaLiveCatalogFilter;
    if (gridFilter.isEmpty || _isStremioCatalogFilter(gridFilter)) {
      return const [];
    }
    final out = <EnginePlugin>[];
    for (final catalog in catalogPlugins) {
      final filterId = EngineService.catalogFilterId(catalog);
      if (!_catalogFilterMatches(filterId, gridFilter)) continue;
      final load = _s._forjaLivePluginLoads[filterId];
      if (load == null || load.loading || load.attempted) continue;
      out.add(catalog);
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
    // `loading` may already be true — dispatcher marks rows before await.
    if (load == null || load.attempted) return;

    if (!load.loading) {
      setState(() {
        _s._forjaLivePluginLoads[filterId] =
            _s._forjaLivePluginLoads[filterId]!.copyWith(loading: true);
      });
    }

    try {
      LiveMatchesEngine.cachePluginMeta(catalog);
      final extraConfig = await _liveCatalogExtraConfig(catalog);
      if (!genAlive()) return;
      final rows = await EngineService.instance.runLiveCatalog(
        catalogPlugin: catalog,
        extraConfig: extraConfig,
      );
      // Always cache on success — chip filter must not discard finished rows.
      if (!genAlive()) return;
      if (LiveMatchesEngine.isIframeCatalogPlugin(catalog)) {
        await LiveMatchesEngine.warmIframeCatalogWebOrigin();
        final streams = rows
            .where((row) =>
                _forjaLiveCatalogRowInHorizon(row, _s._scheduleHorizon))
            .map(_iframeCatalogFromRow)
            .where((s) => s.id.isNotEmpty && s.name.isNotEmpty)
            .toList();
        setState(() {
          _invalidateLiveMatchesGridCache();
          _s._iframeCatalogStreams = [..._s._iframeCatalogStreams, ...streams];
          _s._forjaLivePluginLoads[filterId] =
              _s._forjaLivePluginLoads[filterId]!.copyWith(
            loading: false,
            attempted: true,
            matchCount: streams.length,
            error: null,
          );
          _syncCatalogHydratingState();
        });
        _maybeRebuildSportTabsFromCurrentMatches();
        return;
      }

      final ingestFullDay = LiveMatchesEngine.scheduleFullDayFromConfig(
        catalog.config,
      );
      final Iterable<Map<String, dynamic>> visibleRows = ingestFullDay
          ? rows
          : rows.where(
              (row) => _forjaLiveCatalogRowInHorizon(
                row,
                _s._scheduleHorizon,
                pluginId: filterId,
              ),
            );
      final matchRows = visibleRows
          .map((row) {
            final enriched = Map<String, dynamic>.from(row);
            enriched.putIfAbsent('pluginId', () => filterId);
            return _forjaLiveRowToMatch(enriched);
          })
          .where((m) => m.id.isNotEmpty && m.title.isNotEmpty);
      final uncapped = LiveMatchesEngine.catalogUncappedFromConfig(catalog.config) ||
          LiveMatchesEngine.cachedCatalogUncapped(catalog.id) ||
          LiveMatchesEngine.cachedCatalogUncapped(filterId);
      final matches = uncapped
          ? matchRows.toList()
          : matchRows.take(_kForjaLiveCatalogMaxPerPlugin).toList();
      setState(() {
        _invalidateLiveMatchesGridCache();
        _s._streamedMatches = _sortStreamedLiveFirst([
          ..._s._streamedMatches,
          ...matches,
        ]);
        if (LiveMatchesEngine.isScheduleEnrichCatalogPlugin(catalog)) {
          _syncScheduleEnrichGamesFromMatches();
        }
        if (catalog.supportsLiveBroadcast) {
          final sourceKey =
              LiveSportCapabilities.normalizePluginId(catalog.id);
          putLiveBroadcastIndex(
            [
              for (final row in rows)
                if (row['sportMatchGame'] is Map)
                  _stampBroadcastSource(
                    Map<String, dynamic>.from(row['sportMatchGame'] as Map),
                    sourceKey: sourceKey,
                  ),
            ],
            sourceKey: sourceKey,
          );
        }
        _s._forjaLivePluginLoads[filterId] =
            _s._forjaLivePluginLoads[filterId]!.copyWith(
          loading: false,
          attempted: true,
          matchCount: matches.length,
          error: null,
        );
        _syncCatalogHydratingState();
      });
      _maybeRebuildSportTabsFromCurrentMatches();
      _kickStreamedViewerHydration(matches, gen);
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
        _syncCatalogHydratingState();
      });
      (this as _LiveMatchesData)
          ._scheduleRestoreRefreshFocus(clearWhenSettled: true);
      } finally {
      if (!genAlive() && mounted) {
        final row = _s._forjaLivePluginLoads[filterId];
        if (row != null && row.loading && !row.attempted) {
          setState(() {
            _s._forjaLivePluginLoads[filterId] =
                row.copyWith(loading: false);
          });
        }
      }
    }
  }

  Future<void> _loadOneStremioCatalog({
    required String filterId,
    required int gen,
  }) async {
    bool genAlive() => mounted && gen == _s._forjaLiveLoadGen;
    final load = _s._forjaLivePluginLoads[filterId];
    if (load == null || load.attempted) return;
    final base = _stremioBaseUrlFromCatalogFilter(filterId);
    if (base == null) {
      setState(() {
        _s._forjaLivePluginLoads[filterId] = load.copyWith(
          loading: false,
          attempted: true,
          matchCount: 0,
          error: 'invalid stremio catalog',
        );
        _syncCatalogHydratingState();
      });
      return;
    }

    if (!load.loading) {
      setState(() {
        _s._forjaLivePluginLoads[filterId] =
            load.copyWith(loading: true);
      });
    }

    try {
      final stremio = StremioService();
      final addons =
          await stremio.getAddonsForFeature(StremioAddonFeatures.live);
      if (!genAlive()) return;
      Map<String, dynamic>? addon;
      for (final a in addons) {
        final url = SettingsService.normalizeStremioAddonBaseUrl(
          a['baseUrl']?.toString() ?? '',
        );
        if (url == base) {
          addon = a;
          break;
        }
      }
      if (addon == null) {
        setState(() {
          _s._forjaLivePluginLoads[filterId] =
              _s._forjaLivePluginLoads[filterId]!.copyWith(
            loading: false,
            attempted: true,
            matchCount: 0,
            error: 'addon not installed',
          );
          _syncCatalogHydratingState();
        });
        return;
      }

      final matches = await _fetchStremioSportMatchesForAddon(
        addon,
        service: stremio,
      );
      if (!genAlive()) return;
      setState(() {
        _invalidateLiveMatchesGridCache();
        _s._streamedMatches = _sortStreamedLiveFirst([
          for (final m in _s._streamedMatches)
            if (!m.isStremio ||
                SettingsService.normalizeStremioAddonBaseUrl(m.stremioBaseUrl) !=
                    base)
              m,
          ...matches,
        ]);
        _s._forjaLivePluginLoads[filterId] =
            _s._forjaLivePluginLoads[filterId]!.copyWith(
          loading: false,
          attempted: true,
          matchCount: matches.length,
          error: null,
        );
        _syncCatalogHydratingState();
      });
      _maybeRebuildSportTabsFromCurrentMatches();
    } catch (e) {
      debugPrint('[LiveMatches] Stremio catalog $filterId: $e');
      if (!genAlive()) return;
      setState(() {
        _s._forjaLivePluginLoads[filterId] =
            _s._forjaLivePluginLoads[filterId]!.copyWith(
          loading: false,
          attempted: true,
          matchCount: 0,
          error: '$e',
        );
        _syncCatalogHydratingState();
      });
    } finally {
      if (!genAlive() && mounted) {
        final row = _s._forjaLivePluginLoads[filterId];
        if (row != null && row.loading && !row.attempted) {
          setState(() {
            _s._forjaLivePluginLoads[filterId] =
                row.copyWith(loading: false);
          });
        }
      }
    }
  }

  /// Streamed.pk only reports viewers on `/api/stream/…` — hydrate live cards after catalog ingest.
  void _kickStreamedViewerHydration(
    Iterable<_StreamedMatch> seeds,
    int gen,
  ) {
    final targets = seeds
        .where(
          (m) =>
              m.isLive &&
              m.viewers == 0 &&
              m.isForjaLive &&
              m.sources.isNotEmpty,
        )
        .toList();
    if (targets.isEmpty) return;
    unawaited(() async {
      for (final seed in targets) {
        if (!mounted || gen != _s._forjaLiveLoadGen) return;
        final total = await streamedMatchViewerTotalFromSources(seed);
        if (total <= 0 || !mounted || gen != _s._forjaLiveLoadGen) continue;
        setState(() {
          _invalidateLiveMatchesGridCache();
          final key = _liveEventViewerKey(seed);
          _s._eventStreamViewerTotals[key] = total;
          _s._streamedMatches = _s._streamedMatches.map((m) {
            if (!_sameStreamedEvent(m, seed) || m.viewers > 0) return m;
            return m.withViewerCount(total);
          }).toList();
        });
      }
    }());
  }

  Future<void> _loadForjaLiveCatalogLazy() async {
    final gen = _s._forjaLiveLoadGen;
    _s._catalogFetchedHorizon = _s._scheduleHorizon;
    try {
      await LiveMatchesEngine.warmPluginMeta();
      await EngineService.instance.ensureOfficialInstalled();
      final catalogPlugins =
          await EngineService.instance.listEnabledLiveCatalogPlugins();
      if (!mounted || gen != _s._forjaLiveLoadGen) return;

      _ensureForjaLivePluginLoadsRegistered(catalogPlugins);
      if (!mounted || gen != _s._forjaLiveLoadGen) return;
      await _ensureStremioCatalogLoadsRegistered();
      if (!mounted || gen != _s._forjaLiveLoadGen) return;

      final filter = _activeForjaLiveCatalogFilter;
      if (_isStremioCatalogFilter(filter)) {
        final load = _s._forjaLivePluginLoads[filter];
        if (load != null && !load.attempted && !load.loading) {
          setState(() {
            _s._forjaLivePluginLoads[filter] = load.copyWith(loading: true);
            _syncCatalogHydratingState();
          });
          await _loadOneStremioCatalog(filterId: filter, gen: gen);
        }
        if (mounted && gen == _s._forjaLiveLoadGen) {
          _rebuildSportTabsFromCurrentMatches();
          _syncCatalogHydratingState();
          (this as _LiveMatchesData)
              ._scheduleRestoreRefreshFocus(clearWhenSettled: true);
        }
        return;
      }

      if (catalogPlugins.isEmpty) {
        _setForjaLiveCatalogHydrating(false);
        await _applyScheduleEnrichMerge();
        return;
      }

      final toLoad = _forjaLiveCatalogsToLoad(catalogPlugins);
      if (toLoad.isEmpty) {
        await _applyScheduleEnrichMerge();
        if (mounted && gen == _s._forjaLiveLoadGen) {
          _syncCatalogHydratingState();
        }
        return;
      }

      // Mark loading before any await so empty UI stays on the spinner.
      if (mounted && gen == _s._forjaLiveLoadGen) {
        setState(() {
          for (final catalog in toLoad) {
            final filterId = EngineService.catalogFilterId(catalog);
            final row = _s._forjaLivePluginLoads[filterId];
            if (row == null || row.loading || row.attempted) continue;
            _s._forjaLivePluginLoads[filterId] =
                row.copyWith(loading: true);
          }
          _syncCatalogHydratingState();
        });
      }

      var pending = toLoad.length;
      for (final catalog in toLoad) {
        unawaited(
          _loadOneForjaLiveCatalog(catalog: catalog, gen: gen).whenComplete(() {
            if (!mounted || gen != _s._forjaLiveLoadGen) return;
            pending--;
            if (pending > 0) return;
            _ensureForjaLivePluginFilterValid();
            unawaited(_applyScheduleEnrichMerge());
            if (mounted && gen == _s._forjaLiveLoadGen) {
              _rebuildSportTabsFromCurrentMatches();
              _syncCatalogHydratingState();
              _kickStreamedViewerHydration(_s._streamedMatches, gen);
              (this as _LiveMatchesData)
                  ._scheduleRestoreRefreshFocus(clearWhenSettled: true);
            }
          }),
        );
      }
    } catch (_) {
      if (mounted && gen == _s._forjaLiveLoadGen) {
        _setForjaLiveCatalogHydrating(false);
      }
      rethrow;
    }
  }

  bool _gridCatalogNeedsHydration() {
    if (!_usesForjaLiveLazyCatalog) return false;
    if (_s._forjaLivePluginLoads.isEmpty) return true;
    final filter = _activeForjaLiveCatalogFilter;
    if (filter.isEmpty) return true;
    final load = _forjaLivePluginLoadForFilter(filter);
    return load == null || (!load.attempted && !load.loading);
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
    final sources = _usesForjaLiveLazyCatalog
        ? _catalogSourcesForSportTabs()
        : (iframeCatalog: _s._iframeCatalogStreams, streamed: _s._streamedMatches);

    void addCat(String raw) {
      final id = _normalizeSportId(raw);
      if (id.isEmpty || !seen.add(id)) return;
      cats.add(_Sport(id: id, name: _sportDisplayName(raw, id)));
    }

    if (_usesForjaLiveLazyCatalog) {
      for (final s in sources.iframeCatalog) {
        if (applyWindow &&
            !_iframeCatalogInScheduleFilter(
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

    for (final m in sources.streamed) {
      if (applyWindow &&
          !_streamedMatchInScheduleFilter(
            m,
            status: _s._scheduleStatus,
            horizon: _scheduleHorizonForCatalogMatch(
              m,
              horizon: _s._scheduleHorizon,
              catalogFilter: _s._forjaLivePluginFilter,
            ),
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

    if (cats.length <= 1) {
      if (_sportCategoryIdsEqual(cats, _s._sports) &&
          _s._tabController == null) {
        (this as _LiveMatchesData)
          .._scheduleRestoreRefreshFocus(clearWhenSettled: true)
          .._scheduleRestoreLiveMatchesTvFocus();
        return;
      }
      final oldCtrl = _s._tabController;
      setState(() {
        _s._tabController = null;
        _s._sports = cats;
        _s._sportFilter = 'all';
      });
      _deferTabControllerDispose(oldCtrl);
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
