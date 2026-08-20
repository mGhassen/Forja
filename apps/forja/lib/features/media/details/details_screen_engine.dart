part of 'details_screen.dart';

mixin _DetailsScreenEngine on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

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

  int get _engineBatchLimit =>
      engineSourcesBatchLimit(tv: SourcesPanelTv.isTv(context));

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
    setState(() {
      _s._engineFetchedPluginIds.add(pluginId);
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

  Future<void> _fetchNextEnginePlugin({
    bool reset = false,
    String? onlyId,
    bool chain = false,
  }) async {
    if (!_s._hasEnginePacks || _s._movie.id <= 0) return;
    if (_s._isEngineFetching && !reset && !chain) {
      if (onlyId != null && _s._engineInFlightPluginIds.contains(onlyId)) {
        return;
      }
      if (onlyId == null && _s._engineInFlightPluginIds.isNotEmpty) {
        return;
      }
      if (onlyId != null) {
        EngineService.instance.cancelPending();
        DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
        _s._engineFetchGen++;
        _s._isEngineFetching = false;
        _s._engineInFlightPluginIds.clear();
      }
    }
    if (reset) {
      EngineService.instance.cancelPending();
    }
    final fetchedIds = reset
        ? <String>{}
        : Set<String>.from(_s._engineFetchedPluginIds);
    final limit = onlyId != null ? 1 : _engineBatchLimit;
    final skip = {...fetchedIds, ..._s._engineInFlightPluginIds};
    final batchIds = onlyId != null
        ? <String>[onlyId]
        : nextEnginePluginBatch(
            orderedIds: _orderedEnginePluginIds,
            selectedIds: _s._engineSelectedPluginIds,
            fetchedIds: skip,
            limit: limit,
          );
    if (batchIds.isEmpty) return;
    if (onlyId != null &&
        (!_s._engineSelectedPluginIds.contains(onlyId) ||
            (!reset && fetchedIds.contains(onlyId)))) {
      return;
    }
    final gen = chain ? _s._engineFetchGen : ++_s._engineFetchGen;
    setState(() {
      _s._isEngineFetching = true;
      if (reset) {
        _s._engineStreams = [];
        _s._engineFetchedPluginIds = {};
      }
      if (_s._selectedSourceId == EngineIds.allChip) {
        _s._errorMessage = null;
      }
    });
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    final running = <Future<void>>{};

    void launch(String pluginId) {
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
          running.remove(task);
          if (!mounted || gen != _s._engineFetchGen) return;
          setState(() => _s._engineInFlightPluginIds.remove(pluginId));
          if (onlyId != null) return;
          final slots = limit - _s._engineInFlightPluginIds.length;
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
            launch(id);
          }
        }
      }();
      running.add(task);
    }

    for (final id in batchIds) {
      launch(id);
    }
    while (running.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(running));
    }
    if (!mounted || gen != _s._engineFetchGen) return;
    final pendingAfter = nextEnginePluginId(
      orderedIds: _orderedEnginePluginIds,
      selectedIds: _s._engineSelectedPluginIds,
      fetchedIds: _s._engineFetchedPluginIds,
    );
    final continueWalk = shouldContinueNuvioScraperWalk(
      explicitScraper: onlyId != null,
      hasPendingSelected: pendingAfter != null,
    );
    setState(() {
      _s._isEngineFetching = continueWalk;
      if (!continueWalk) _s._engineInFlightPluginIds.clear();
      if (!continueWalk &&
          _s._selectedSourceId == EngineIds.allChip &&
          _s._engineStreams.isEmpty &&
          pendingAfter == null) {
        _s._errorMessage = 'No streams found from selected Forja plugins';
      }
    });
    if (continueWalk) {
      await _fetchNextEnginePlugin(chain: true);
    }
  }
}
