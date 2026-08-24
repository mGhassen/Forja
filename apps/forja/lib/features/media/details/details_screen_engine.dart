part of 'details_screen.dart';

class _EngineAutoPick {
  const _EngineAutoPick({
    required this.pluginId,
    required this.stream,
    required this.sources,
  });

  final String pluginId;
  final Map<String, dynamic> stream;
  final List<StreamSource> sources;
}

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

  /// Green Play hooks into the same Forja panel pool (not a second extractor).
  void Function()? _engineAutoSyncOverlay;
  Future<void> Function(String pluginId, List<Map<String, dynamic>> streams)?
      _engineAutoOnPluginDone;

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

  void _hydrateEngineStreamsFromSessionCache() {
    if (_s._engineStreams.isNotEmpty) return;
    final cached = CatalogSourcesSessionCache.readEngine(_s._catalogCacheKey);
    if (cached == null) return;
    void apply() {
      _s._engineStreams = cached.streams;
      _s._engineFetchedPluginIds = cached.fetchedPluginIds;
      _s._errorMessage = null;
    }
    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
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
    final onDone = _engineAutoOnPluginDone;
    if (onDone != null) {
      unawaited(onDone(pluginId, List<Map<String, dynamic>>.from(streams)));
    } else if (streams.isNotEmpty) {
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
    _engineAutoSyncOverlay?.call();
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
        if (!mounted || gen != _s._engineFetchGen) {
          _engineAutoSyncOverlay?.call();
          return;
        }
        setState(() => _s._engineInFlightPluginIds.remove(pluginId));
        _engineFillPool(gen: gen, type: type);
        _engineAutoSyncOverlay?.call();
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

  String _enginePluginLabel(String pluginId) {
    for (final pack in _s._enginePacks) {
      for (final p in pack.plugins) {
        if (p.id == pluginId) {
          final name = p.name.trim();
          return name.isNotEmpty ? name : pluginId;
        }
      }
    }
    return pluginId;
  }

  /// Green Play: same Forja panel pool as Sources → Forja.
  /// First plugin that yields a working stream plays; rest cancel.
  Future<void> _startEngineAutoPlayback() async {
    if (_s._isEngineAutoExtracting) return;
    if (_s._playSourceWebstreaming) return;
    if (!_s._playSourceEngine || !_s._playSourceEngineAutoStart) return;

    final playGen = ++_s._engineAutoPlayGen;
    if (mounted) {
      setState(() => _s._isEngineAutoExtracting = true);
    } else {
      _s._isEngineAutoExtracting = true;
    }
    _s._engineAutoExtractionCancelled = false;

    bool playAborted() =>
        !mounted ||
        playGen != _s._engineAutoPlayGen ||
        _s._engineAutoExtractionCancelled;

    final fadeOutNotifier = ValueNotifier(false);
    final messageNotifier = ValueNotifier('Finding Forja servers…');
    final probeNotifier = ValueNotifier<List<StreamProviderProbe>>([]);
    final failureNotifier = ValueNotifier<ResolveFailure?>(null);
    BuildContext? loadingDialogContext;
    var openedPlayer = false;
    Completer<_EngineAutoPick?>? hitCompleter;

    List<ChangeNotifier> overlayNotifiers() => [
      fadeOutNotifier,
      messageNotifier,
      failureNotifier,
      probeNotifier,
    ];

    void dismissLoading() {
      final ctx = loadingDialogContext;
      loadingDialogContext = null;
      if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
    }

    void clearAutoHooks() {
      _engineAutoOnPluginDone = null;
      _engineAutoSyncOverlay = null;
    }

    void cancelEngineAutoPlay() {
      if (playGen != _s._engineAutoPlayGen) return;
      _s._engineAutoExtractionCancelled = true;
      clearAutoHooks();
      _engineAbortWork();
      final pending = hitCompleter;
      if (pending != null && !pending.isCompleted) pending.complete(null);
      dismissLoading();
      if (mounted) _s._claimTvHeroPlayAfterPlayer();
      if (mounted) {
        setState(() => _s._isEngineAutoExtracting = false);
      } else {
        _s._isEngineAutoExtracting = false;
      }
    }

    showLoadingOverlayDialog(
      context,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return LoadingOverlay(
          movie: _s._movie,
          messageNotifier: messageNotifier,
          providerProbesNotifier: probeNotifier,
          fadeOutNotifier: fadeOutNotifier,
          failureNotifier: failureNotifier,
          subtitle: _s._loadingOverlaySubtitle(),
          onCancel: cancelEngineAutoPlay,
        );
      },
    );
    await Future<void>.delayed(Duration.zero);
    if (playAborted()) {
      dismissLoading();
      disposeLoadingOverlayNotifiers(overlayNotifiers());
      _s._isEngineAutoExtracting = false;
      return;
    }

    try {
      await EngineService.instance.ensureBundledInstalled();
      if (playAborted()) return;
      await _checkAndFetchEngine();
      if (playAborted() || !mounted) return;
      _hydrateEngineStreamsFromSessionCache();
      if (playAborted()) return;

      final packs = _s._enginePacks;
      final pluginIds = _scopedSelectedEnginePluginIds();
      if (mounted) {
        setState(() {
          _s._hasEnginePacks = packs.isNotEmpty;
        });
      }
      if (pluginIds.isEmpty) {
        final action = Completer<void>();
        failureNotifier.value = ResolveFailure(
          title: 'Couldn’t start playback',
          detail:
              'No Forja plugins are selected for this title. Open Sources → Forja and turn on providers.',
          primaryLabel: 'Close',
          primaryIcon: Icons.close_rounded,
          onPrimary: () {
            if (!action.isCompleted) action.complete();
          },
        );
        await action.future;
        return;
      }

      final statusById = <String, StreamProviderProbeStatus>{
        for (final id in pluginIds) id: StreamProviderProbeStatus.pending,
      };
      final race = Completer<_EngineAutoPick?>();
      hitCompleter = race;
      var probingCount = 0;

      // Panel/session already loaded → never show WAITING for those chips.
      for (final id in pluginIds) {
        if (!_s._engineFetchedPluginIds.contains(id)) continue;
        final hasRows = _s._engineStreams.any(
          (s) => engineStreamBelongsToPlugin(s, id),
        );
        statusById[id] = hasRows
            ? StreamProviderProbeStatus.trying
            : StreamProviderProbeStatus.failed;
      }

      void publishProbes() {
        probeNotifier.value = [
          for (var i = 0; i < pluginIds.length; i++)
            StreamProviderProbe(
              id: pluginIds[i],
              label: _enginePluginLabel(pluginIds[i]),
              status: statusById[pluginIds[i]]!,
              isPreferred: i == 0,
            ),
        ];
      }

      void syncOverlayFromPool() {
        if (race.isCompleted) return;
        for (final id in pluginIds) {
          final cur = statusById[id]!;
          if (cur == StreamProviderProbeStatus.success ||
              cur == StreamProviderProbeStatus.failed) {
            continue;
          }
          if (_s._engineInFlightPluginIds.contains(id)) {
            statusById[id] = StreamProviderProbeStatus.trying;
          } else if (!_s._engineFetchedPluginIds.contains(id)) {
            statusById[id] = StreamProviderProbeStatus.pending;
          } else if (cur == StreamProviderProbeStatus.pending) {
            // Fetched while overlay still said WAITING — promote to CHECKING.
            final hasRows = _s._engineStreams.any(
              (s) => engineStreamBelongsToPlugin(s, id),
            );
            statusById[id] = hasRows
                ? StreamProviderProbeStatus.trying
                : StreamProviderProbeStatus.failed;
          }
        }
        publishProbes();
      }

      void maybeCompleteEmpty() {
        if (race.isCompleted || playAborted()) return;
        final allFetched =
            pluginIds.every(_s._engineFetchedPluginIds.contains);
        if (!allFetched || probingCount > 0 || _engineWorkActive) return;
        race.complete(null);
      }

      Future<void> onPluginDone(
        String pluginId,
        List<Map<String, dynamic>> streams,
      ) async {
        if (playAborted() || race.isCompleted) return;
        if (!pluginIds.contains(pluginId)) return;

        final rows = sortEngineCatalogStreamRows(streams);
        if (rows.isEmpty) {
          statusById[pluginId] = StreamProviderProbeStatus.failed;
          publishProbes();
          maybeCompleteEmpty();
          return;
        }

        probingCount++;
        statusById[pluginId] = StreamProviderProbeStatus.trying;
        publishProbes();
        messageNotifier.value =
            'Checking ${_enginePluginLabel(pluginId)}…';

        for (final row in rows) {
          if (playAborted() || race.isCompleted) break;
          final sources = await _buildProbedEnginePlaySources(
            _s,
            [row],
            isAborted: playAborted,
            preferFirst: row,
          );
          if (sources.isEmpty) continue;
          statusById[pluginId] = StreamProviderProbeStatus.success;
          publishProbes();
          if (!race.isCompleted) {
            // First UP wins — stop the panel pool.
            _engineAbortWork();
            race.complete(
              _EngineAutoPick(
                pluginId: pluginId,
                stream: row,
                sources: sources,
              ),
            );
          }
          probingCount--;
          return;
        }

        statusById[pluginId] = StreamProviderProbeStatus.failed;
        publishProbes();
        probingCount--;
        maybeCompleteEmpty();
      }

      _engineAutoSyncOverlay = syncOverlayFromPool;
      _engineAutoOnPluginDone = onPluginDone;
      publishProbes();

      // Already in panel/session cache — check first loaded chip immediately.
      final cachedIds = [
        for (final id in pluginIds)
          if (_s._engineFetchedPluginIds.contains(id)) id,
      ];
      if (cachedIds.isNotEmpty) {
        final firstLabel = _enginePluginLabel(cachedIds.first);
        messageNotifier.value = 'Checking $firstLabel…';
      }
      for (final id in cachedIds) {
        if (playAborted() || race.isCompleted) break;
        final cached = _s._engineStreams
            .where((s) => engineStreamBelongsToPlugin(s, id))
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        await onPluginDone(id, cached);
      }

      if (!race.isCompleted && !playAborted()) {
        final pending = [
          for (final id in pluginIds)
            if (!_s._engineFetchedPluginIds.contains(id)) id,
        ];
        if (pending.isEmpty) {
          maybeCompleteEmpty();
        } else {
          // Same loader Sources → Forja uses.
          unawaited(() async {
            await _fetchNextEnginePlugin();
            while (!playAborted() &&
                !race.isCompleted &&
                (_engineWorkActive || probingCount > 0)) {
              await Future<void>.delayed(const Duration(milliseconds: 40));
            }
            maybeCompleteEmpty();
          }());
          syncOverlayFromPool();
        }
      }

      final hit = playAborted() ? null : await race.future;
      clearAutoHooks();
      if (playAborted()) return;

      if (hit != null) {
        openedPlayer = true;
        _syncPanelToEngineAutoPick(hit);
        await _playEngineAutoFromProbedSources(
          sources: hit.sources,
          primaryRow: hit.stream,
          startPosition: _s._startPositionForAutoPlay(fromRoute: false),
          loadingDialogContext: loadingDialogContext,
          fadeOutNotifier: fadeOutNotifier,
          messageNotifier: messageNotifier,
          isAborted: playAborted,
        );
        return;
      }

      final resolveRow = await firstEngineCatalogResolveRow(
        rows: [
          for (final id in pluginIds)
            ..._s._engineStreams.where(
              (s) => engineStreamBelongsToPlugin(s, id),
            ),
        ],
        profile: _s._playbackProfile,
        settings: _s._settings,
      );
      if (resolveRow != null && !playAborted()) {
        openedPlayer = true;
        final pluginId =
            resolveRow['_enginePluginId']?.toString() ?? pluginIds.first;
        _syncPanelToEngineAutoPick(
          _EngineAutoPick(
            pluginId: pluginId,
            stream: resolveRow,
            sources: const [],
          ),
        );
        await _playEngineAutoResolveRow(
          resolveRow,
          startPosition: _s._startPositionForAutoPlay(fromRoute: false),
          loadingDialogContext: loadingDialogContext,
          fadeOutNotifier: fadeOutNotifier,
          isAborted: playAborted,
        );
        return;
      }

      final action = Completer<bool>();
      failureNotifier.value = ResolveFailure(
        title: 'Couldn’t start playback',
        detail:
            'None of the Forja plugins returned a working stream right now.',
        primaryLabel: 'Try again',
        onPrimary: () {
          if (!action.isCompleted) action.complete(true);
        },
        secondaryLabel: 'Close',
        onSecondary: () {
          if (!action.isCompleted) action.complete(false);
        },
      );
      final retry = await action.future;
      dismissLoading();
      if (mounted) {
        setState(() => _s._isEngineAutoExtracting = false);
      } else {
        _s._isEngineAutoExtracting = false;
      }
      if (retry && mounted) {
        unawaited(_startEngineAutoPlayback());
      }
    } finally {
      clearAutoHooks();
      if (!openedPlayer) dismissLoading();
      disposeLoadingOverlayNotifiers(overlayNotifiers());
      if (mounted) {
        setState(() => _s._isEngineAutoExtracting = false);
      } else {
        _s._isEngineAutoExtracting = false;
      }
    }
  }

  void _syncPanelToEngineAutoPick(_EngineAutoPick pick) {
    final catalogUrl = pick.stream['url']?.toString();
    final base =
        pick.stream['_addonBaseUrl']?.toString() ??
        EngineIds.pluginChip(pick.pluginId);
    void apply() {
      _s._playingPanelKind = EngineIds.kind;
      _s._playingAddonBaseUrl = base;
      _s._playingCatalogUrl = catalogUrl;
      _s._panelKindFilter = EngineIds.kind;
      // Keep chip selection as panel left it — only mark playing row.
      _s._selectedSourceId = EngineIds.pluginChip(pick.pluginId);
      _s._panelSourceIdByKind[EngineIds.kind] = _s._selectedSourceId;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _playEngineAutoFromProbedSources({
    required List<StreamSource> sources,
    required Map<String, dynamic>? primaryRow,
    required Duration? startPosition,
    required BuildContext? loadingDialogContext,
    required ValueNotifier<bool> fadeOutNotifier,
    required ValueNotifier<String>? messageNotifier,
    required bool Function() isAborted,
  }) async {
    if (isAborted() || !mounted || sources.isEmpty) return;
    messageNotifier?.value = 'Opening player…';
    final primary = sources.first;
    final stream = primaryRow ?? <String, dynamic>{};
    final isTv = _s._movie.mediaType == 'tv';
    final stremioId =
        widget.stremioItem?['id']?.toString() ?? _s._movie.imdbId;
    final stremioAddonBaseUrl =
        stream['_addonBaseUrl']?.toString() ?? _s._selectedSourceId;
    final ctx = loadingDialogContext;
    Future<void> openPlayer() => AppRouter.openPlayer(
      context,
      streamUrl: primary.url,
      title: _s._movie.title,
      headers: primary.headers,
      movie: _s._movie,
      selectedSeason: isTv ? _s._selectedSeason : null,
      selectedEpisode: isTv ? _s._selectedEpisode : null,
      startPosition: startPosition,
      activeProvider:
          primary.providerId ?? catalogHttpPlayProviderId(stream),
      sources: sources,
      pinSource: false,
      streamsPrevalidated: true,
      externalSubtitles: catalogStreamExternalSubtitles(stream),
      stremioId: stremioId,
      stremioAddonBaseUrl: stremioAddonBaseUrl,
      fadeTransition: ctx != null,
    );
    if (ctx != null && ctx.mounted) {
      await crossfadeLoadingOverlayToPlayer(
        loadingDialogContext: ctx,
        fadeOutNotifier: fadeOutNotifier,
        openPlayer: openPlayer,
      );
    } else {
      await openPlayer();
    }
    if (mounted) _s._claimTvHeroPlayAfterPlayer();
  }

  Future<void> _playEngineAutoResolveRow(
    Map<String, dynamic> stream, {
    required Duration? startPosition,
    required BuildContext? loadingDialogContext,
    required ValueNotifier<bool> fadeOutNotifier,
    required bool Function() isAborted,
  }) async {
    if (isAborted() || !mounted) return;
    final isTv = _s._movie.mediaType == 'tv';
    final stremioId =
        widget.stremioItem?['id']?.toString() ?? _s._movie.imdbId;
    final stremioAddonBaseUrl =
        stream['_addonBaseUrl']?.toString() ?? _s._selectedSourceId;

    if (!await ensureLanP2pPlayback(context)) return;
    if (isAborted() || !mounted) return;
    _s._streamCancelled = false;

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: _s._playbackProfile,
      settings: _s._settings,
      season: isTv ? _s._selectedSeason : null,
      episode: isTv ? _s._selectedEpisode : null,
      isCancelled: () => isAborted() || _s._streamCancelled,
      onStatus: (_) {},
    );
    if (isAborted() || !mounted) return;
    if (resolved is! StremioPlayable) return;

    final ctx = loadingDialogContext;
    Future<void> openPlayer() => AppRouter.openPlayer(
      context,
      streamUrl: resolved.streamUrl,
      title: _s._movie.title,
      magnetLink: resolved.magnetLink,
      movie: _s._movie,
      selectedSeason: isTv ? _s._selectedSeason : null,
      selectedEpisode: isTv ? _s._selectedEpisode : null,
      fileIndex: resolved.fileIndex,
      startPosition: startPosition,
      activeProvider: catalogHttpPlayProviderId(stream),
      externalSubtitles: catalogStreamExternalSubtitles(stream),
      stremioId: stremioId,
      stremioAddonBaseUrl: stremioAddonBaseUrl,
      fadeTransition: ctx != null,
    );
    if (ctx != null && ctx.mounted) {
      await crossfadeLoadingOverlayToPlayer(
        loadingDialogContext: ctx,
        fadeOutNotifier: fadeOutNotifier,
        openPlayer: openPlayer,
      );
    } else {
      await openPlayer();
    }
    if (mounted) _s._claimTvHeroPlayAfterPlayer();
  }
}
