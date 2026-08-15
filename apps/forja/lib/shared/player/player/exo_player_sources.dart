part of 'exo_player_screen.dart';

mixin _ExoPlayerSources on ConsumerState<ExoPlayerScreen> {
  _ExoPlayerScreenState get _s => this as _ExoPlayerScreenState;

  bool get _usesCatalogSourcesPanel {
    if (widget.movie == null) return false;
    final magnet = _s._activeMagnet ?? widget.magnetLink;
    if (magnet != null && magnet.isNotEmpty) return true;
    return isCatalogSourcesMode(
      _s._currentProvider ?? widget.activeProvider,
    );
  }

  String? _initialCatalogSourceKind() {
    final base = widget.stremioAddonBaseUrl;
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) {
      return 'torrents';
    }
    final provider = widget.activeProvider;
    if (provider == 'torrent') return 'torrents';
    if (provider == 'stremio_direct') return 'stremio';
    return null;
  }

  bool get _hasStreamPickerSources {
    if (_usesCatalogSourcesPanel) return false;
    final hasProviders =
        widget.providers != null && widget.providers!.isNotEmpty;
    final hasSources =
        _s._currentSources != null && _s._currentSources!.isNotEmpty;
    return hasProviders || hasSources;
  }

  String _activeServerLabel() {
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid != null &&
        pid.isNotEmpty &&
        widget.providers != null &&
        widget.providers!.containsKey(pid)) {
      return PlayerProviderMenu.snackbarLabel(pid, widget.providers![pid]);
    }
    if (_s._sources.isNotEmpty) {
      final title = _s._sources[_s._sourceIndex].title.trim();
      if (title.isNotEmpty) return title;
    }
    return 'Sources';
  }

  void _seedSourceSession(List<_ExoSource> ranked) {
    _s._currentProvider = widget.activeProvider;
    _s._currentUrl =
        ranked.isNotEmpty ? ranked.first.url : widget.mediaPath;
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      _s._currentSources = dedupeStreamSources(widget.sources!);
    } else if (ranked.isNotEmpty) {
      _s._currentSources = [
        for (final s in ranked)
          StreamSource(
            url: s.url,
            title: s.title,
            type: 'video',
            headers: s.headers,
          ),
      ];
    } else {
      _s._currentSources = [
        StreamSource(
          url: widget.mediaPath,
          title: widget.title,
          type: 'video',
          headers: widget.headers,
        ),
      ];
    }
    final pid = _s._currentProvider;
    final sources = _s._currentSources;
    if (pid != null &&
        pid.isNotEmpty &&
        sources != null &&
        sources.isNotEmpty) {
      _s._providerSourcesCache.value = {
        ..._s._providerSourcesCache.value,
        pid: sources,
      };
    }
  }

  Future<List<StreamSource>?> _loadServer(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _s._providerSourcesCache.value[providerId];
      if (cached != null && cached.isNotEmpty) return cached;
      if (providerId == _s._currentProvider &&
          _s._currentSources != null &&
          _s._currentSources!.isNotEmpty) {
        return _s._currentSources;
      }
    } else {
      final next = Map<String, List<StreamSource>>.from(
        _s._providerSourcesCache.value,
      )..remove(providerId);
      _s._providerSourcesCache.value = next;
    }

    for (final id in _s._providerLoadGens.keys.toList()) {
      if (id == providerId) continue;
      _s._providerLoadGens[id] = (_s._providerLoadGens[id] ?? 0) + 1;
    }
    DomainStreamProviderResolver.cancelAllPending();

    final gen = (_s._providerLoadGens[providerId] ?? 0) + 1;
    _s._providerLoadGens[providerId] = gen;
    _s.ref.read(playerResolveStatusProvider.notifier).setLoading(providerId);

    try {
      if (widget.movie == null || widget.providers == null) return null;
      final hit = await PlayerSourceResolve.resolvePinnedForMovie(
        movie: widget.movie!,
        providers: widget.providers!,
        providerId: providerId,
        season: widget.selectedSeason ?? 1,
        episode: widget.hubEpisodeNumber?.toInt() ??
            widget.selectedEpisode ??
            1,
        isCancelled: () =>
            _s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen,
        bypassDiskCache: forceRefresh,
      );
      if (_s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen) {
        return null;
      }
      if (hit != null && hit.streamSources.isNotEmpty) {
        if (hit.providerId.isNotEmpty && hit.providerId != providerId) {
          _s.ref.read(playerResolveStatusProvider.notifier).setError(
                'No streams found',
              );
          return null;
        }
        final sources = sourcesOwnedByProvider(
          providerId,
          dedupeStreamSources(hit.streamSources),
        );
        if (sources.isEmpty) {
          _s.ref.read(playerResolveStatusProvider.notifier).setError(
                'No streams found',
              );
          return null;
        }
        _s._providerSourcesCache.value = {
          ..._s._providerSourcesCache.value,
          providerId: sources,
        };
        if (providerId == _s._currentProvider &&
            (forceRefresh ||
                (_s._currentSources?.length ?? 0) < sources.length)) {
          _s._currentSources = sources;
        }
        _s.ref.read(playerResolveStatusProvider.notifier).setReady();
        return sources;
      }
      _s.ref.read(playerResolveStatusProvider.notifier).setError(
            'No streams found',
          );
      return null;
    } catch (_) {
      if (!_s._disposed && (_s._providerLoadGens[providerId] ?? 0) == gen) {
        _s.ref.read(playerResolveStatusProvider.notifier).setError(
              'Failed to load sources',
            );
      }
      return null;
    }
  }

  Future<bool> _checkStreamSource(
    StreamSource source,
    int index, [
    String? providerId,
  ]) async {
    final pid = providerId ?? _s._currentProvider ?? '';
    try {
      var openUrl = source.url;
      Map<String, String>? headers = source.headers ?? widget.headers;

      if (animeHlsNeedsPngStripFor(openUrl, sourceKey: pid)) {
        final stripped = await applyAnimePngStripIfNeeded(
          StreamSource(
            url: openUrl,
            title: source.title,
            type: source.type,
            headers: headers,
          ),
          sourceKey: pid,
        );
        openUrl = stripped.url;
        headers = stripped.headers;
      }

      return await probeStreamSourceUrl(openUrl, headers, sourceKey: pid);
    } catch (_) {
      return false;
    }
  }

  Future<void> _selectStreamFromDialog(
    String providerId,
    StreamSource source,
    int index,
  ) async {
    final switchGen = ++_s._fallbackGen;
    setState(() {
      _s._hasError = false;
      _s._errorMessage = '';
    });
    final resumeAt = _s._position;
    final statusId = 'source-switch-$index';
    final label = source.title.trim().isEmpty ? 'Stream' : source.title;
    _s._statusController.upsert(
      statusId,
      label,
      kind: StatusRouletteKind.loading,
    );

    try {
      var openUrl = source.url;
      Map<String, String>? headers = source.headers ?? widget.headers;

      if (animeHlsNeedsPngStripFor(openUrl, sourceKey: providerId)) {
        final stripped = await applyAnimePngStripIfNeeded(
          StreamSource(
            url: openUrl,
            title: source.title,
            type: source.type,
            headers: headers,
          ),
          sourceKey: providerId,
        );
        openUrl = stripped.url;
        headers = stripped.headers;
      }

      final reachable = await probeStreamSourceUrl(
        openUrl,
        headers,
        sourceKey: providerId,
      );
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      if (!reachable) {
        _s._statusController.upsert(
          statusId,
          label,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }

      DomainStreamProviderResolver.cancelAllPending();
      try {
        await ExoPlayerBridge.stop(_s._viewId);
      } catch (_) {}
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;

      final cached = _s._providerSourcesCache.value[providerId];
      var sessionSources = preferFullerProviderSources(
        providerId: providerId,
        live: _s._currentSources,
        cached: cached,
      );
      if (sessionSources.isEmpty) {
        sessionSources = sourcesOwnedByProvider(
          providerId,
          dedupeStreamSources([source]),
        );
      }
      if (sessionSources.isEmpty) {
        sessionSources = dedupeStreamSources([source]);
      }
      // Keep selected row identity even when live had collapsed to a singleton.
      final match = sessionSources.indexWhere((s) => s.url == source.url);
      final at = match >= 0 ? match : index.clamp(0, sessionSources.length - 1);
      if (at >= 0 && at < sessionSources.length) {
        final prev = sessionSources[at];
        sessionSources = [
          for (var i = 0; i < sessionSources.length; i++)
            if (i == at)
              source.copyWith(
                providerId: source.providerId ?? prev.providerId ?? providerId,
                catalogUrl: source.catalogUrl ?? prev.catalogUrl ?? source.url,
              )
            else
              sessionSources[i],
        ];
      }

      setState(() {
        _s._currentProvider = providerId;
        _s._currentSources = sessionSources;
        _s._providerSourcesCache.value = {
          ..._s._providerSourcesCache.value,
          providerId: sessionSources,
        };
        _s._currentUrl = openUrl;
        _s._hasError = false;
        _s._errorMessage = '';
        _s._sources = [
          for (final s in sessionSources)
            _ExoSource(
              url: s.url,
              title: s.title,
              headers: s.headers ?? headers,
            ),
        ];
        _s._sourceIndex = at.clamp(0, _s._sources.length - 1);
        final playMatch = _s._sources.indexWhere((s) => s.url == source.url);
        if (playMatch >= 0) _s._sourceIndex = playMatch;
      });

      _s._opening = false;
      _s._startPositionApplied = true;
      _s._preferredSubtitleApplied = false;
      final prepared = await _s._prepareOpenSubtitles(
        (widget.externalSubtitles ?? [])
            .where((s) => (s['url'] ?? '').toString().isNotEmpty)
            .toList(),
      );
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      _s._sideloadedSubtitles = prepared;
      final maxH = await SettingsService().getMaxPlaybackHeight();
      final caps = exoVodCapsForMaxPlaybackHeight(maxH);
      await ExoPlayerBridge.open(
        viewId: _s._viewId,
        url: openUrl,
        headers: headers,
        startPosition: resumeAt.inSeconds > 0 ? resumeAt : Duration.zero,
        subtitles: prepared
            .map(
              (s) => {
                'url': s['url']!,
                'lang': s['lang'] ?? 'und',
                'label': s['label'] ?? s['lang'] ?? 'und',
              },
            )
            .toList(),
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
      );
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      await ExoPlayerBridge.setVolume(_s._viewId, _s._volume / 100.0);
      if (_s._rate != 1.0) {
        await ExoPlayerBridge.setRate(_s._viewId, _s._rate);
      }
      await ExoPlayerBridge.setResizeMode(_s._viewId, _s._resizeMode);
      _s._statusController.complete();
      widget.onPlaybackStarted?.call();
      if (_s._isTv) _s._claimPlayFocus();
    } catch (e) {
      debugPrint('[ExoPlayer] source switch failed: $e');
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      _s._statusController.upsert(
        statusId,
        label,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _showTorrentSourcesPanel() async {
    final movie = widget.movie;
    if (movie == null) return;
    _s._hideTimer?.cancel();
    await PlayerSourcesPanel.show(
      context: context,
      movie: movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      currentMagnet: _s._activeMagnet ?? widget.magnetLink,
      currentStreamUrl: _s._currentUrl ?? widget.mediaPath,
      preferredKind: _s._catalogSourceKind,
      currentAddonBaseUrl:
          _s._catalogAddonBaseUrl ?? widget.stremioAddonBaseUrl,
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    final debridService = await settings.getDebridService();
    final precheck = classifyStremioStream(
      stream,
      PlatformPlayback.capabilities,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (precheck == null) {
      await _switchStremioMagnetSource(stream);
      return;
    }

    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    final switchGen = ++_s._fallbackGen;
    final statusId = 'source-stremio-${stream.hashCode}';
    _s._statusController.upsert(
      statusId,
      title,
      kind: StatusRouletteKind.loading,
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._fallbackAborted(switchGen)) return;

    try {
      try {
        await ExoPlayerBridge.stop(_s._viewId);
      } catch (_) {}
      final resolved = await resolveStremioStream(
        stream: stream,
        profile: PlatformPlayback.capabilities,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;

      if (resolved is! StremioPlayable) {
        final msg = resolved is StremioResolveFailure
            ? resolved.message
            : 'Failed to resolve stream';
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        if (msg.isNotEmpty) {
          debugPrint(
            '[ExoPlayer] ${catalogStreamKindLabel(stream)} switch failed: $msg',
          );
        }
        return;
      }

      await _openCatalogHttpInExo(
        url: resolved.streamUrl,
        headers: resolved.headers,
        switchGen: switchGen,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;

      setState(() {
        _s._currentUrl = resolved.streamUrl;
        _s._activeMagnet = resolved.magnetLink;
        _s._hasError = false;
        _s._errorMessage = '';
        _s._currentSources = null;
        final base = stream['_addonBaseUrl']?.toString();
        _s._catalogAddonBaseUrl = base;
        final magnet = resolved.magnetLink;
        final localTorrent = magnet != null &&
            magnet.isNotEmpty &&
            isLocalTorrentStreamUrl(resolved.streamUrl);
        _s._catalogSourceKind = localTorrent
            ? 'torrents'
            : ((base != null && base.startsWith('nuvio:'))
                ? 'nuvio'
                : 'stremio');
        _s._currentProvider = 'stremio_direct';
      });
      _s._statusController.complete();
      widget.onPlaybackStarted?.call();
      _s._startHideTimer();
      if (_s._isTv) _s._claimPlayFocus();
    } catch (e) {
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      debugPrint(
        '[ExoPlayer] ${catalogStreamKindLabel(stream)} switch failed: $e',
      );
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _switchStremioMagnetSource(Map<String, dynamic> stream) async {
    if (_s._loadingNextEp) return;
    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    if (!mounted) return;
    if (!await ensureLanP2pPlayback(context)) return;
    if (!mounted) return;
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    _s._beginEpisodeLoading(
      label: title,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final debridService = await settings.getDebridService();
      _s._setEpisodeLoadingStatus(
        playbackResolveLabel(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
      );

      final resolved = await resolveStremioStream(
        stream: stream,
        profile: PlatformPlayback.capabilities,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
      if (!mounted) return;
      if (resolved is! StremioPlayable || resolved.streamUrl.isEmpty) {
        final msg =
            resolved is StremioResolveFailure && resolved.message.isNotEmpty
                ? resolved.message
                : 'Failed to resolve stream';
        debugPrint(
          '[ExoPlayer] ${catalogStreamKindLabel(stream)} switch failed: $msg',
        );
        await _s._failEpisodeLoading(msg);
        return;
      }

      _s._setEpisodeLoadingStatus('Opening stream…');
      TorrentStreamService().retainForExternalHandoff = true;

      final season = widget.selectedSeason;
      final episode = widget.selectedEpisode;
      final nextTitle = widget.movie != null && season != null && episode != null
          ? '${widget.movie!.title} - S$season E$episode'
          : widget.title;
      final base = stream['_addonBaseUrl']?.toString();
      final magnet = resolved.magnetLink;

      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: resolved.streamUrl,
            title: nextTitle,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: magnet,
            fileIndex: resolved.fileIndex,
            headers: resolved.headers.isEmpty ? null : resolved.headers,
            activeProvider: 'stremio_direct',
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: base ?? widget.stremioAddonBaseUrl,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        '[ExoPlayer] ${catalogStreamKindLabel(stream)} switch failed: $e',
      );
      await _s._failEpisodeLoading('Failed to resolve stream');
    }
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    if (_s._loadingNextEp) return;
    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    if (!mounted) return;
    if (!await ensureLanP2pPlayback(context)) return;
    if (!mounted) return;
    _s._beginEpisodeLoading(
      label: result.name,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final debridService = await settings.getDebridService();
      _s._setEpisodeLoadingStatus(
        playbackResolveLabel(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
      );

      final playback = await resolveMagnetForPlayback(
        magnet: result.magnet,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: PlatformPlayback.capabilities.localTorrentEngine,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
      if (!mounted) return;
      if (playback == null || playback.url.isEmpty) {
        await _s._failEpisodeLoading('Torrent stream failed to start');
        return;
      }

      _s._setEpisodeLoadingStatus('Opening stream…');
      TorrentStreamService().retainForExternalHandoff = true;

      final season = widget.selectedSeason;
      final episode = widget.selectedEpisode;
      final nextTitle = widget.movie != null && season != null && episode != null
          ? '${widget.movie!.title} - S$season E$episode'
          : widget.title;

      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: playback.url,
            title: nextTitle,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: result.magnet,
            fileIndex: playback.fileIndex,
            activeProvider: 'torrent',
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ExoPlayer] Torrent switch failed: $e');
      await _s._failEpisodeLoading('Torrent stream failed to start');
    }
  }

  Future<void> _openCatalogHttpInExo({
    required String url,
    required Map<String, String>? headers,
    required int switchGen,
  }) async {
    final resumeAt = _s._position;
    final prepared = await _s._prepareOpenSubtitles(
      (widget.externalSubtitles ?? [])
          .where((s) => (s['url'] ?? '').toString().isNotEmpty)
          .toList(),
    );
    if (!mounted || _s._fallbackAborted(switchGen)) return;
    _s._sideloadedSubtitles = prepared;
    _s._opening = false;
    _s._startPositionApplied = true;
    _s._preferredSubtitleApplied = false;
    final maxH = await SettingsService().getMaxPlaybackHeight();
    final caps = exoVodCapsForMaxPlaybackHeight(maxH);
    await ExoPlayerBridge.open(
      viewId: _s._viewId,
      url: url,
      headers: headers,
      startPosition: resumeAt.inSeconds > 0 ? resumeAt : Duration.zero,
      subtitles: prepared
          .map(
            (s) => {
              'url': s['url']!,
              'lang': s['lang'] ?? 'und',
              'label': s['label'] ?? s['lang'] ?? 'und',
            },
          )
          .toList(),
      maxVideoHeight: caps.maxVideoHeight,
      maxVideoBitrate: caps.maxVideoBitrate,
    );
    if (!mounted || _s._fallbackAborted(switchGen)) return;
    await ExoPlayerBridge.setVolume(_s._viewId, _s._volume / 100.0);
    if (_s._rate != 1.0) {
      await ExoPlayerBridge.setRate(_s._viewId, _s._rate);
    }
    await ExoPlayerBridge.setResizeMode(_s._viewId, _s._resizeMode);
  }

  Future<void> _showSourcesDialog(BuildContext anchorContext) async {
    if (!_hasStreamPickerSources) return;
    await PlayerServerStreamDialog.show(
      context,
      providers: widget.providers,
      currentProviderId: _s._currentProvider ?? widget.activeProvider,
      currentUrl: _s._currentUrl,
      currentSources: _s._currentSources,
      providerSourcesCache: _s._providerSourcesCache,
      onLoadServer: _loadServer,
      onSelectStream: _selectStreamFromDialog,
      onCheckStream: _checkStreamSource,
      movie: widget.movie,
      anchorContext: anchorContext,
    );
    // TV: opener (Sources) restored by playerMenuRestoreReturnFocus.
  }
}
