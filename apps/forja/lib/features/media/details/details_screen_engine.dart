part of 'details_screen.dart';

mixin _DetailsScreenEngine on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  final Set<Future<void>> _enginePoolTasks = {};
  int _enginePoolLimit = kEngineSourcesBatchDesktop;

  Future<void> _checkAndFetchEngine() async {
    try {
      final packs = await EngineService.instance.listSourcesPanelPacks();
      final enabledIds = enabledEnginePluginIds(packs);
      final saved = _s._engineSelectionHydrated
          ? null
          : await EngineService.instance.loadSourcesSelectedPluginIds(
              enabledIds: enabledIds,
            );
      if (!mounted) return;
      setState(() {
        _s._hasEnginePacks = enabledIds.isNotEmpty;
        _s._enginePacks = packs;
        if (!_s._engineSelectionHydrated) {
          _s._engineSelectedPluginIds = saved ?? {};
          _s._engineSelectionHydrated = true;
        } else {
          _s._engineSelectedPluginIds = filterEngineSelectedPluginIds(
            savedIds: _s._engineSelectedPluginIds,
            enabledIds: enabledIds,
          );
        }
      });
    } catch (_) {}
  }

  List<String> get _orderedEnginePluginIds =>
      orderedEnginePluginIds(_s._enginePacks);

  List<String> get _pendingEnginePluginIds => [
    for (final id in _orderedEnginePluginIds)
      if (_s._engineSelectedPluginIds.contains(id) &&
          !_s._engineFetchedPluginIds.contains(id))
        id,
  ];

  bool get _engineWorkActive =>
      _s._isEngineFetching ||
      _s._engineInFlightPluginIds.isNotEmpty ||
      _enginePoolTasks.isNotEmpty;

  bool get _engineFullAllSelected => engineFullAllSelected(
    enabledIds: enabledEnginePluginIds(_s._enginePacks),
    selectedIds: _s._engineSelectedPluginIds,
  );

  Future<void> _runAndApplyEnginePlugin({
    required String pluginId,
    required String type,
    required int gen,
  }) async {
    final year = _s._movie.releaseDate.length >= 4
        ? _s._movie.releaseDate.substring(0, 4)
        : null;
    EngineExtractResult? batch;
    try {
      batch = await EngineService.instance.runPluginIsolated(
        pluginId: pluginId,
        tmdbId: _s._movie.id.toString(),
        type: type,
        season: _s._movie.mediaType == 'tv' ? _s._selectedSeason : null,
        episode: _s._movie.mediaType == 'tv' ? _s._selectedEpisode : null,
        title: _s._movie.title,
        year: year,
        movie: _s._movie,
        allowHostFallback: false,
      );
    } catch (e) {
      debugPrint('[engine] plugin $pluginId failed: $e');
    }
    if (!mounted || gen != _s._engineFetchGen) return;
    if (!_s._engineSelectedPluginIds.contains(pluginId)) return;
    setState(() {
      _s._engineFetchedPluginIds.add(pluginId);
      _s._engineStreams.removeWhere(
        (s) => engineStreamBelongsToPlugin(s, pluginId),
      );
      if (batch != null && batch.streams.isNotEmpty) {
        _s._engineStreams.addAll(batch.streams);
      }
    });
    CatalogSourcesSessionCache.writeEngine(
      _s._catalogCacheKey,
      List<Map<String, dynamic>>.from(_s._engineStreams),
      fetchedPluginIds: _s._engineFetchedPluginIds,
    );
    if (batch != null && batch.streams.isNotEmpty) {
      _s._maybeAutoPlay();
    }
  }

  void _engineFillPool({required int gen, required String type}) {
    if (!mounted || gen != _s._engineFetchGen) return;
    final slots = _enginePoolLimit - _s._engineInFlightPluginIds.length;
    if (slots <= 0) return;
    final next = nextEnginePluginBatch(
      orderedIds: _orderedEnginePluginIds,
      selectedIds: _s._engineSelectedPluginIds,
      fetchedIds: {
        ..._s._engineFetchedPluginIds,
        ..._s._engineInFlightPluginIds,
      },
      limit: slots,
    );
    for (final id in next) {
      _engineStartPlugin(pluginId: id, type: type, gen: gen);
    }
  }

  void _engineStartPlugin({
    required String pluginId,
    required String type,
    required int gen,
  }) {
    if (!mounted || gen != _s._engineFetchGen) return;
    if (_s._engineInFlightPluginIds.contains(pluginId) ||
        _s._engineFetchedPluginIds.contains(pluginId)) {
      return;
    }
    setState(() => _s._engineInFlightPluginIds.add(pluginId));
    late final Future<void> task;
    task = () async {
      try {
        await _runAndApplyEnginePlugin(
          pluginId: pluginId,
          type: type,
          gen: gen,
        );
      } finally {
        _enginePoolTasks.remove(task);
        if (!mounted || gen != _s._engineFetchGen) return;
        setState(() => _s._engineInFlightPluginIds.remove(pluginId));
        _engineFillPool(gen: gen, type: type);
      }
    }();
    _enginePoolTasks.add(task);
  }

  Future<void> _engineDrainPool({required int gen, required String type}) async {
    while (mounted && gen == _s._engineFetchGen) {
      while (_enginePoolTasks.isNotEmpty &&
          mounted &&
          gen == _s._engineFetchGen) {
        await Future.wait(List<Future<void>>.of(_enginePoolTasks));
      }
      if (!mounted || gen != _s._engineFetchGen) return;
      if (_pendingEnginePluginIds.isEmpty) break;
      _engineFillPool(gen: gen, type: type);
      if (_enginePoolTasks.isEmpty) break;
    }
  }

  Future<void> _fetchNextEnginePlugin({
    bool reset = false,
    bool refresh = false,
  }) async {
    if (!_s._hasEnginePacks || _s._movie.id <= 0) return;
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    if (_s._isEngineFetching && !reset && !refresh) {
      _engineFillPool(gen: _s._engineFetchGen, type: type);
      return;
    }
    if (reset || refresh) {
      EngineService.instance.cancelPending();
      _enginePoolTasks.clear();
    }
    final startingAllWalk =
        !reset && !refresh && _engineFullAllSelected && !_s._isEngineFetching;
    final gen = ++_s._engineFetchGen;
    _enginePoolLimit = engineSourcesBatchLimit(
      tv: SourcesPanelTv.isTv(context),
    );
    setState(() {
      _s._isEngineFetching = true;
      if (reset) {
        _s._engineStreams = [];
        _s._engineFetchedPluginIds = {};
        _s._engineInFlightPluginIds.clear();
      } else if (refresh) {
        _s._engineFetchedPluginIds.removeAll(_s._engineSelectedPluginIds);
        _s._engineInFlightPluginIds.clear();
      } else if (startingAllWalk) {
        engineClearSelectedWalkState(
          selectedIds: _s._engineSelectedPluginIds,
          streams: _s._engineStreams,
          fetchedIds: _s._engineFetchedPluginIds,
        );
        _s._engineInFlightPluginIds.clear();
      }
      if (_s._selectedSourceId == EngineIds.allChip) {
        _s._errorMessage = null;
      }
    });
    _engineFillPool(gen: gen, type: type);
    await _engineDrainPool(gen: gen, type: type);
    if (!mounted || gen != _s._engineFetchGen) return;
    final stillPending = _pendingEnginePluginIds.isNotEmpty;
    setState(() {
      _s._isEngineFetching = stillPending;
      if (!stillPending) _s._engineInFlightPluginIds.clear();
      if (!stillPending &&
          _s._selectedSourceId == EngineIds.allChip &&
          _s._engineStreams.isEmpty) {
        _s._errorMessage = 'No streams found from selected Forja plugins';
      }
    });
  }
}
