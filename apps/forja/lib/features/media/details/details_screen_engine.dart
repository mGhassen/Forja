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

List<Map<String, dynamic>> _sortEngineStreamRows(
  List<Map<String, dynamic>> rows,
) {
  final copy = List<Map<String, dynamic>>.from(rows);
  copy.sort((a, b) {
    final aUrl = a['url']?.toString() ?? '';
    final bUrl = b['url']?.toString() ?? '';
    final aBox = isMovieBoxCdnStreamUrl(aUrl);
    final bBox = isMovieBoxCdnStreamUrl(bUrl);
    if (aBox != bBox) return aBox ? 1 : -1;
    return 0;
  });
  return copy;
}

/// Classify → proxy → HTTP probe. Hover green uses the same probe but mpv can
/// still fail — callers must pass [streamsPrevalidated: false] so the player
/// can hop siblings or re-resolve when open fails.
Future<List<StreamSource>> _buildProbedEnginePlaySources(
  _DetailsScreenState s,
  List<Map<String, dynamic>> rows, {
  required bool Function() isAborted,
  Map<String, dynamic>? preferFirst,
}) async {
  final useDebrid = await s._settings.useDebridForStreams();
  final debridService = await s._settings.getDebridService();
  var ordered = _sortEngineStreamRows(rows);
  if (preferFirst != null) {
    final preferUrl = preferFirst['url']?.toString();
    ordered = [
      preferFirst,
      ...ordered.where((r) => r['url']?.toString() != preferUrl),
    ];
  }
  final sources = <StreamSource>[];
  for (final row in ordered) {
    if (isAborted() || !s.mounted) break;
    final check = classifyStremioStream(
      row,
      s._playbackProfile,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (check is! StremioPlayable) continue;
    final proxied = await proxyCatalogHttpStreamIfNeeded(
      streamUrl: check.streamUrl,
      headers: check.headers,
      stream: row,
    );
    if (isAborted() || !s.mounted) break;
    final probeRow = Map<String, dynamic>.from(row)
      ..['url'] = proxied.url
      ..['headers'] = proxied.headers;
    if (!await probeSourcesPanelStream(probeRow)) continue;
    final url = proxied.url;
    final pluginId = row['_enginePluginId']?.toString() ?? '';
    // MovieBlast progressive is Matroska; labeling mp4 confuses some opens.
    final type = url.contains('.m3u8')
        ? 'hls'
        : (pluginId == 'movieblast' ? 'mkv' : 'mp4');
    sources.add(
      StreamSource(
        url: url,
        title: (row['title'] ?? row['name'] ?? 'Forja').toString(),
        type: type,
        headers: proxied.headers,
        providerId: catalogHttpPlayProviderId(row),
      ),
    );
  }
  return sources;
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
      final hits = await _raceEnginePluginsForAuto(
        pluginIds: pluginIds,
        playGen: playGen,
        probeNotifier: probeNotifier,
        messageNotifier: messageNotifier,
        isAborted: playAborted,
        maxHits: 1,
      );
      if (playAborted()) return;

      if (hits.isEmpty) {
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
        // Clear flag before retry so `_startEngineAutoPlayback` isn't a no-op.
        // Notifier dispose stays in `finally`.
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

      openedPlayer = true;
      final hit = hits.first;
      await _playEngineAutoWinner(
        hit.batch,
        preferFirst: hit.stream,
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

  /// Push Forja Auto JS output into the same store Sources reads
  /// (`_engineStreams` + session TTL cache). Same merge as chip extract.
  void _mergeEngineAutoResult(
    String pluginId,
    List<Map<String, dynamic>> streams,
  ) {
    void apply() {
      _s._engineFetchedPluginIds.add(pluginId);
      _s._engineStreams.removeWhere(
        (s) => engineStreamBelongsToPlugin(s, pluginId),
      );
      if (streams.isNotEmpty) {
        _s._engineStreams.addAll(streams);
        // Keep existing chips; ensure this plugin is selected so rows show.
        _s._engineSelectedPluginIds.add(pluginId);
      }
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
    CatalogSourcesSessionCache.writeEngine(
      _s._catalogCacheKey,
      List<Map<String, dynamic>>.from(_s._engineStreams),
      fetchedPluginIds: _s._engineFetchedPluginIds,
    );
  }

  Future<List<_EngineAutoHit>> _raceEnginePluginsForAuto({
    required List<String> pluginIds,
    required int playGen,
    required ValueNotifier<List<StreamProviderProbe>> probeNotifier,
    required ValueNotifier<String> messageNotifier,
    required bool Function() isAborted,
    int maxHits = 1,
  }) async {
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    final year = _s._movie.releaseDate.length >= 4
        ? _s._movie.releaseDate.substring(0, 4)
        : null;
    final limit = engineSourcesBatchLimit(tv: SourcesPanelTv.isTv(context));
    final hits = <_EngineAutoHit>[];
    final completer = Completer<List<_EngineAutoHit>>();
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
        // Do not return from try on empty/fail — that skips fill() after finally.
        if (!isAborted() && !completer.isCompleted) {
          final streams = batch?.streams ?? const <Map<String, dynamic>>[];
          // Same store as Sources panel — Auto is not a separate extract path.
          _mergeEngineAutoResult(pluginId, streams);
          if (streams.isEmpty) {
            statusById[pluginId] = StreamProviderProbeStatus.failed;
            publishProbes();
          } else {
            // Probe each JS stream; other plugins keep extracting in parallel.
            final pick = await _firstProbedEngineStream(
              streams,
              isAborted: isAborted,
              orSettled: () => completer.isCompleted,
            );
            if (isAborted() || completer.isCompleted) {
              // fall through to finally + fill gate
            } else if (pick == null) {
              statusById[pluginId] = StreamProviderProbeStatus.failed;
              publishProbes();
            } else {
              statusById[pluginId] = StreamProviderProbeStatus.success;
              publishProbes();
              hits.add(
                _EngineAutoHit(
                  pluginId: pluginId,
                  stream: pick,
                  batch: List<Map<String, dynamic>>.from(streams),
                ),
              );
              if (hits.length >= maxHits && !completer.isCompleted) {
                completer.complete(List<_EngineAutoHit>.from(hits));
              }
            }
          }
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
        if (!completer.isCompleted) {
          completer.complete(List<_EngineAutoHit>.from(hits));
        }
        return;
      }
      fill();
      if (nextIndex >= pluginIds.length &&
          inFlight == 0 &&
          !completer.isCompleted) {
        completer.complete(List<_EngineAutoHit>.from(hits));
      }
    };

    fill();
    if (pluginIds.isEmpty) return const <_EngineAutoHit>[];
    final result = await completer.future;
    if (isAborted()) return const <_EngineAutoHit>[];
    return result;
  }

  /// Walk sorted JS streams: classify → probe → first reachable wins.
  /// Other plugin extracts keep running while this probes.
  Future<Map<String, dynamic>?> _firstProbedEngineStream(
    List<Map<String, dynamic>> streams, {
    required bool Function() isAborted,
    required bool Function() orSettled,
  }) async {
    final useDebrid = await _s._settings.useDebridForStreams();
    final debridService = await _s._settings.getDebridService();
    if (isAborted() || orSettled()) return null;

    for (final stream in _sortEngineStreamRows(streams)) {
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
      if (check is! StremioPlayable) continue;

      final proxied = await proxyCatalogHttpStreamIfNeeded(
        streamUrl: check.streamUrl,
        headers: check.headers,
        stream: stream,
      );
      if (isAborted() || orSettled()) return null;

      final probeRow = Map<String, dynamic>.from(stream)
        ..['url'] = proxied.url
        ..['headers'] = proxied.headers;

      final ok = await probeSourcesPanelStream(probeRow);
      if (isAborted() || orSettled()) return null;
      final title = (stream['title'] ?? stream['name'] ?? '').toString();
      if (ok) {
        debugPrint('[engine-auto] probe ok: $title');
        return stream;
      }
      debugPrint('[engine-auto] probe fail: $title');
    }
    return null;
  }

  Future<void> _playEngineAutoWinner(
    List<Map<String, dynamic>> streams, {
    Map<String, dynamic>? preferFirst,
    required Duration? startPosition,
    required BuildContext? loadingDialogContext,
    required ValueNotifier<bool> fadeOutNotifier,
    required bool Function() isAborted,
  }) async {
    if (isAborted() || !mounted || streams.isEmpty) return;
    final stream = preferFirst ?? streams.first;
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
      final sources = await _buildProbedEnginePlaySources(
        _s,
        streams,
        isAborted: isAborted,
        preferFirst: stream,
      );
      if (sources.isEmpty) return;
      final primary = sources.first;
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
        activeProvider: primary.providerId ?? catalogHttpPlayProviderId(stream),
        sources: sources,
        pinSource: false,
        streamsPrevalidated: false,
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
