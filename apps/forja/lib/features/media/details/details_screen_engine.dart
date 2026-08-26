part of 'details_screen.dart';

Future<List<StreamSource>> _buildProbedEnginePlaySources(
  _DetailsScreenState s,
  List<Map<String, dynamic>> rows, {
  required bool Function() isAborted,
  Map<String, dynamic>? preferFirst,
  ValueNotifier<String>? messageNotifier,
}) {
  return buildProbedEngineCatalogSources(
    profile: s._playbackProfile,
    settings: s._settings,
    rows: rows,
    isAborted: () => isAborted() || !s.mounted,
    preferFirst: preferFirst,
    messageNotifier: messageNotifier,
  );
}

mixin _DetailsScreenEngine on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  final Set<Future<void>> _enginePoolTasks = {};
  int _enginePoolLimit = kEngineSourcesBatchDesktop;

  Future<void> _checkAndFetchEngine() async {
    try {
      final packs = await EngineService.instance.listSourcesPanelPacks();
      final enabledIds = enabledEnginePluginIds(packs);
      final panelCategory = _s._enginePanelCategory;
      final scope = EngineCategories.matchingPluginIds(
        packs: packs,
        categories: EngineCategories.defaultsForPanelCategory(panelCategory),
      );
      final saved = _s._engineSelectionHydrated
          ? null
          : await EngineService.instance.loadSourcesSelectedPluginIds(
              enabledIds: enabledIds,
              panelCategory: panelCategory,
              selectAllScopeIds: scope,
            );
      if (!mounted) return;
      setState(() {
        _s._hasEnginePacks = enabledIds.isNotEmpty;
        _s._enginePacks = packs;
        if (!_s._engineSelectionHydrated) {
          _s._engineSelectedPluginIds = EngineCategories.scopeSelectionIfFullAll(
            selected: saved ?? {},
            enabledIds: enabledIds,
            scope: scope,
          );
          _s._engineAllMode = engineFullAllSelected(
            enabledIds: scope.isNotEmpty ? scope : enabledIds,
            selectedIds: _s._engineSelectedPluginIds,
          );
          _s._engineViewFilterPluginIds = {};
          _s._engineSelectionHydrated = true;
        } else {
          _s._engineSelectedPluginIds = filterEngineSelectedPluginIds(
            savedIds: _s._engineSelectedPluginIds,
            enabledIds: enabledIds,
          );
          if (_s._engineAllMode) {
            _s._engineAllMode = engineFullAllSelected(
              enabledIds: scope.isNotEmpty ? scope : enabledIds,
              selectedIds: _s._engineSelectedPluginIds,
            );
            if (!_s._engineAllMode) _s._engineViewFilterPluginIds = {};
          }
        }
      });
    } catch (_) {}
  }

  List<String> get _orderedEnginePluginIds =>
      orderedEnginePluginIds(_s._enginePacks);

  /// Same plugin row as Forja tab chips (category scope + chip selection).
  List<String> _scopedSelectedEnginePluginIds() {
    final cats = _s._effectiveEngineCategories;
    final selected = _s._engineSelectedPluginIds;
    return [
      for (final id in _orderedEnginePluginIds)
        if (selected.contains(id) && _enginePluginVisibleForAuto(id, cats))
          id,
    ];
  }

  bool _enginePluginVisibleForAuto(String pluginId, Set<String> cats) {
    for (final pack in _s._enginePacks) {
      for (final p in pack.plugins) {
        if (p.id != pluginId) continue;
        return EngineCategories.pluginChipVisible(
          plugin: p,
          visibleCategories: cats,
          selectedPluginIds: _s._engineSelectedPluginIds,
        );
      }
    }
    return false;
  }

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

  /// Selected chips that should spin: selected + not yet fetched, while work runs.
  Set<String> get _engineLoadingPluginIds {
    if (!_engineWorkActive) return const {};
    return {
      for (final id in _s._engineSelectedPluginIds)
        if (!_s._engineFetchedPluginIds.contains(id)) id,
    };
  }

  /// Stop Forja pool work (empty chip selection, kind leave, hard cancel).
  void _engineAbortWork({bool clearFetched = false}) {
    _s._engineFetchGen++;
    _s._isEngineFetching = false;
    _s._engineInFlightPluginIds.clear();
    _enginePoolTasks.clear();
    _s._engineDiscardPluginIds.clear();
    EngineService.instance.cancelPending();
    if (clearFetched) _s._engineFetchedPluginIds.clear();
  }

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
    if (!mounted || gen != _s._engineFetchGen) {
      if (mounted) {
        setState(() => _s._engineInFlightPluginIds.remove(pluginId));
      } else {
        _s._engineInFlightPluginIds.remove(pluginId);
      }
      return;
    }
    if (_s._engineDiscardPluginIds.remove(pluginId)) {
      if (mounted) {
        setState(() => _s._engineInFlightPluginIds.remove(pluginId));
      }
      return;
    }
    if (!_s._engineSelectedPluginIds.contains(pluginId)) {
      setState(() => _s._engineInFlightPluginIds.remove(pluginId));
      return;
    }
    // Clear inFlight in the same setState as fetched so loading chips match.
    setState(() {
      _s._engineFetchedPluginIds.add(pluginId);
      _s._engineInFlightPluginIds.remove(pluginId);
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
    final streams = batch?.streams ?? const <Map<String, dynamic>>[];
    if (streams.isNotEmpty) {
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
    if (next.isEmpty) return;
    final started = <String>[];
    setState(() {
      for (final id in next) {
        if (_s._engineInFlightPluginIds.contains(id) ||
            _s._engineFetchedPluginIds.contains(id)) {
          continue;
        }
        _s._engineInFlightPluginIds.add(id);
        started.add(id);
      }
    });
    for (final id in started) {
      _engineLaunchPlugin(pluginId: id, type: type, gen: gen);
    }
  }

  void _engineLaunchPlugin({
    required String pluginId,
    required String type,
    required int gen,
  }) {
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
      if (_enginePoolTasks.isEmpty) {
        break;
      }
    }
  }

  Future<void> _fetchNextEnginePlugin({
    bool reset = false,
    bool refresh = false,
  }) async {
    if (!_s._hasEnginePacks || _s._movie.id <= 0) return;
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    if (_s._isEngineFetching && !reset && !refresh) {
      // Pool still live → join. Flag stuck with empty pool → revive.
      if (_enginePoolTasks.isNotEmpty || _pendingEnginePluginIds.isEmpty) {
        _engineFillPool(gen: _s._engineFetchGen, type: type);
        return;
      }
      refresh = true;
    }
    if (reset || refresh) {
      EngineService.instance.cancelPending();
      _enginePoolTasks.clear();
    }
    _s._isEngineFetching = true;
    final gen = ++_s._engineFetchGen;
    _enginePoolLimit = engineSourcesBatchLimit(
      tv: SourcesPanelTv.isTv(context),
    );
    setState(() {
      if (reset) {
        _s._engineStreams = [];
        _s._engineFetchedPluginIds = {};
        _s._engineInFlightPluginIds.clear();
      } else if (refresh) {
        _s._engineFetchedPluginIds.removeAll(_s._engineSelectedPluginIds);
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

  /// Green Play → shared [runEngineAutoPlay] (same as Anime / Asian Drama).
  Future<void> _startEngineAutoPlayback({bool fromEngineResume = false}) async {
    if (_s._isEngineAutoExtracting) return;
    if (!fromEngineResume && _s._playSourceWebstreaming) return;
    if (!fromEngineResume &&
        (!_s._playSourceEngine || !_s._playSourceEngineAutoStart)) {
      return;
    }
    if (fromEngineResume && !_s._playSourceEngine) return;

    final playGen = ++_s._engineAutoPlayGen;
    if (mounted) {
      setState(() => _s._isEngineAutoExtracting = true);
    } else {
      _s._isEngineAutoExtracting = true;
    }
    _s._engineAutoExtractionCancelled = false;

    // Stop panel pool — auto uses the shared session-cache race, not a fork.
    _engineAbortWork();
    await _checkAndFetchEngine();
    if (!mounted ||
        playGen != _s._engineAutoPlayGen ||
        _s._engineAutoExtractionCancelled) {
      if (mounted) {
        setState(() => _s._isEngineAutoExtracting = false);
      } else {
        _s._isEngineAutoExtracting = false;
      }
      return;
    }

    final isTv = _s._movie.mediaType == 'tv';
    final progress = _s._lastProgress;
    final resumePos = fromEngineResume
        ? (widget.startPosition ??
            (progress != null
                ? resumeStartPositionFromProgress(progress)
                : null))
        : _s._startPositionForAutoPlay(fromRoute: false);
    final pinPlugin = resumePos != null && resumePos > Duration.zero
        ? enginePluginIdFromProgress(progress)
        : null;
    try {
      await runEngineAutoPlay(
        context: context,
        movie: _s._movie,
        engineCategory: _s._enginePanelCategory,
        season: isTv ? _s._selectedSeason : null,
        episode: isTv ? _s._selectedEpisode : null,
        startPosition: resumePos,
        preferredPluginId: pinPlugin,
        savedStreamUrl: progress?['streamUrl'] as String?,
        loadingSubtitle: _s._loadingOverlaySubtitle(),
        stremioId: widget.stremioItem?['id']?.toString() ?? _s._movie.imdbId,
        selectedPluginIds: _scopedSelectedEnginePluginIds().toSet(),
        packs: _s._enginePacks.isNotEmpty ? _s._enginePacks : null,
        onCacheUpdated: (streams, fetched) {
          void apply() {
            _s._engineStreams = streams;
            _s._engineFetchedPluginIds = fetched;
          }
          if (mounted) {
            setState(apply);
          } else {
            apply();
          }
        },
        onPick: _syncPanelToEngineAutoPick,
        onCancelUi: () {
          if (playGen != _s._engineAutoPlayGen) return;
          _s._engineAutoExtractionCancelled = true;
          _engineAbortWork();
          if (mounted) _s._claimTvHeroPlayAfterPlayer();
        },
      );
    } finally {
      if (mounted) {
        setState(() => _s._isEngineAutoExtracting = false);
      } else {
        _s._isEngineAutoExtracting = false;
      }
      if (mounted) _s._claimTvHeroPlayAfterPlayer();
    }
  }

  void _syncPanelToEngineAutoPick(EngineAutoPlayPick pick) {
    final catalogUrl = pick.stream['url']?.toString();
    void apply() {
      _s._playingPanelKind = EngineIds.kind;
      _s._playingCatalogUrl = catalogUrl;
      _s._panelKindFilter = EngineIds.kind;
      // Keep Forja multi-select chips as-is — only switch tab + remember catalog.
      _s._selectedSourceId = EngineIds.allChip;
      _s._panelSourceIdByKind[EngineIds.kind] = EngineIds.allChip;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }
}
