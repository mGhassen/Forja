part of 'details_screen.dart';

class _EngineAutoHit {
  const _EngineAutoHit({
    required this.pluginId,
    required this.stream,
    required this.batch,
  });

  final String pluginId;
  final Map<String, dynamic> stream;
  final List<Map<String, dynamic>> batch;
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

  /// Green Play when Forja auto start is on and Webstreaming is off.
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

    void cancelEngineAutoPlay() {
      if (playGen != _s._engineAutoPlayGen) return;
      _s._engineAutoExtractionCancelled = true;
      EngineService.instance.cancelPending();
      _s._engineFetchGen++;
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
      final packs = await EngineService.instance.listSourcesPanelPacks();
      if (playAborted() || !mounted) return;
      final pluginIds = orderedEnginePluginIds(packs);
      setState(() {
        _s._enginePacks = packs;
        _s._hasEnginePacks = pluginIds.isNotEmpty;
      });
      if (pluginIds.isEmpty) {
        final action = Completer<void>();
        failureNotifier.value = ResolveFailure(
          title: 'Couldn’t start playback',
          detail: 'No Forja plugins are enabled. Turn some on in Settings → Forja plugins.',
          primaryLabel: 'Close',
          primaryIcon: Icons.close_rounded,
          onPrimary: () {
            if (!action.isCompleted) action.complete();
          },
        );
        await action.future;
        return;
      }

      probeNotifier.value = [
        for (var i = 0; i < pluginIds.length; i++)
          StreamProviderProbe(
            id: pluginIds[i],
            label: _enginePluginLabel(pluginIds[i]),
            status: StreamProviderProbeStatus.pending,
            isPreferred: i == 0,
          ),
      ];

      final startPosition = _s._startPositionForAutoPlay(fromRoute: false);
      final hit = await _raceEnginePluginsForAuto(
        pluginIds: pluginIds,
        playGen: playGen,
        probeNotifier: probeNotifier,
        messageNotifier: messageNotifier,
        isAborted: playAborted,
      );
      if (playAborted()) return;

      if (hit == null) {
        final action = Completer<bool>();
        failureNotifier.value = ResolveFailure(
          title: 'Couldn’t start playback',
          detail: 'None of the Forja plugins returned a working stream right now.',
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
        disposeLoadingOverlayNotifiers(overlayNotifiers());
        if (mounted) {
          setState(() => _s._isEngineAutoExtracting = false);
        } else {
          _s._isEngineAutoExtracting = false;
        }
        if (retry && mounted) {
          unawaited(_startEngineAutoPlayback());
        }
        return;
      }

      // Do not snap Sources chips / session cache to the auto winner — that
      // made reopen show the last-played plugin instead of the user's chips.
      openedPlayer = true;
      await _playEngineAutoWinner(
        hit.stream,
        startPosition: startPosition,
        loadingDialogContext: loadingDialogContext,
        fadeOutNotifier: fadeOutNotifier,
        isAborted: playAborted,
      );
    } finally {
      if (!openedPlayer) dismissLoading();
      disposeLoadingOverlayNotifiers(overlayNotifiers());
      if (mounted) {
        setState(() => _s._isEngineAutoExtracting = false);
      } else {
        _s._isEngineAutoExtracting = false;
      }
    }
  }

  Future<_EngineAutoHit?> _raceEnginePluginsForAuto({
    required List<String> pluginIds,
    required int playGen,
    required ValueNotifier<List<StreamProviderProbe>> probeNotifier,
    required ValueNotifier<String> messageNotifier,
    required bool Function() isAborted,
  }) async {
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    final year = _s._movie.releaseDate.length >= 4
        ? _s._movie.releaseDate.substring(0, 4)
        : null;
    final limit = engineSourcesBatchLimit(tv: SourcesPanelTv.isTv(context));
    final completer = Completer<_EngineAutoHit?>();
    var nextIndex = 0;
    var inFlight = 0;
    final statusById = <String, StreamProviderProbeStatus>{
      for (final id in pluginIds) id: StreamProviderProbeStatus.pending,
    };

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

    late final void Function() fill;
    late final Future<void> Function(String pluginId) launch;

    fill = () {
      while (inFlight < limit &&
          nextIndex < pluginIds.length &&
          !completer.isCompleted &&
          !isAborted()) {
        final id = pluginIds[nextIndex++];
        unawaited(launch(id));
      }
    };

    launch = (String pluginId) async {
      inFlight++;
      statusById[pluginId] = StreamProviderProbeStatus.trying;
      publishProbes();
      messageNotifier.value = 'Checking ${_enginePluginLabel(pluginId)}…';
      try {
        final batch = await EngineService.instance.runPluginIsolated(
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
        if (isAborted() || completer.isCompleted) return;
        final streams = batch?.streams ?? const <Map<String, dynamic>>[];
        if (streams.isEmpty) {
          statusById[pluginId] = StreamProviderProbeStatus.failed;
          publishProbes();
          return;
        }

        messageNotifier.value =
            'Probing ${_enginePluginLabel(pluginId)}…';
        final pick = await _pickProbedEngineStream(
          streams,
          isAborted: isAborted,
          orSettled: () => completer.isCompleted,
        );
        if (isAborted() || completer.isCompleted) return;
        if (pick == null) {
          statusById[pluginId] = StreamProviderProbeStatus.failed;
          publishProbes();
          return;
        }

        statusById[pluginId] = StreamProviderProbeStatus.success;
        publishProbes();
        if (!completer.isCompleted) {
          completer.complete(
            _EngineAutoHit(
              pluginId: pluginId,
              stream: pick,
              batch: List<Map<String, dynamic>>.from(streams),
            ),
          );
          EngineService.instance.cancelPending();
          _s._engineFetchGen++;
        }
      } catch (e) {
        debugPrint('[engine-auto] plugin $pluginId failed: $e');
        if (!isAborted() && !completer.isCompleted) {
          statusById[pluginId] = StreamProviderProbeStatus.failed;
          publishProbes();
        }
      } finally {
        inFlight--;
      }
      if (completer.isCompleted) return;
      if (isAborted()) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      fill();
      if (nextIndex >= pluginIds.length &&
          inFlight == 0 &&
          !completer.isCompleted) {
        completer.complete(null);
      }
    };

    fill();
    if (pluginIds.isEmpty) return null;
    final result = await completer.future;
    if (isAborted()) return null;
    return result;
  }

  /// First classify-able HTTP stream whose URL still responds (skip dead CDNs).
  Future<Map<String, dynamic>?> _pickProbedEngineStream(
    List<Map<String, dynamic>> streams, {
    required bool Function() isAborted,
    required bool Function() orSettled,
  }) async {
    final useDebrid = await _s._settings.useDebridForStreams();
    final debridService = await _s._settings.getDebridService();
    if (isAborted() || orSettled()) return null;

    for (final stream in streams) {
      if (isAborted() || orSettled()) return null;
      final check = classifyStremioStream(
        stream,
        _s._playbackProfile,
        useDebrid: useDebrid,
        debridService: debridService,
      );
      if (check is StremioExternalLink || check is StremioResolveFailure) {
        continue;
      }
      if (check is! StremioPlayable) {
        // Magnet / debrid row — rare on Forja HTTP; take it without probe.
        return stream;
      }
      final pid = catalogHttpPlayProviderId(stream);
      final ok = await probeStreamSourceUrl(
        check.streamUrl,
        check.headers,
        sourceKey: pid,
      );
      if (isAborted() || orSettled()) return null;
      if (ok) {
        debugPrint(
          '[engine-auto] probe ok $pid '
          '${check.streamUrl.length > 80 ? '${check.streamUrl.substring(0, 80)}…' : check.streamUrl}',
        );
        return stream;
      }
      debugPrint(
        '[engine-auto] probe fail $pid — try next row',
      );
    }
    return null;
  }

  Future<void> _playEngineAutoWinner(
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

    final useDebrid = await _s._settings.useDebridForStreams();
    final debridService = await _s._settings.getDebridService();
    if (isAborted() || !mounted) return;

    final precheck = classifyStremioStream(
      stream,
      _s._playbackProfile,
      useDebrid: useDebrid,
      debridService: debridService,
    );

    if (precheck is StremioPlayable) {
      final proxied = await proxyCatalogHttpStreamIfNeeded(
        streamUrl: precheck.streamUrl,
        headers: precheck.headers,
        stream: stream,
      );
      if (isAborted() || !mounted) return;
      final ctx = loadingDialogContext;
      Future<void> openPlayer() => AppRouter.openPlayer(
        context,
        streamUrl: proxied.url,
        title: _s._movie.title,
        headers: proxied.headers,
        movie: _s._movie,
        selectedSeason: isTv ? _s._selectedSeason : null,
        selectedEpisode: isTv ? _s._selectedEpisode : null,
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
      return;
    }

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
