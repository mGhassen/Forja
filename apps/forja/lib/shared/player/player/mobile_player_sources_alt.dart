part of 'mobile_player_screen.dart';

mixin _MobilePlayerSourcesAlt on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  Future<void> _showTorrentSourcesPanel() async {
    final movie = widget.movie;
    if (movie == null) return;
    _s._hideTimer?.cancel();
    final session = widget.enginePlaySession;
    final ep = widget.selectedEpisode;
    final epNum = ep ?? 1;
    PlayerSourcesPanel.show(
      context: context,
      movie: movie,
      season: widget.selectedSeason,
      episode: ep,
      currentMagnet: _s._activeMagnet ?? widget.magnetLink,
      currentStreamUrl: _s._currentUrl ?? widget.mediaPath,
      currentPlayingCatalogUrl: _s._currentPlayingCatalogUrl,
      currentPlayingRowKey: _s._catalogStreamRowKey,
      preferredKind: _s._catalogSourceKind,
      currentAddonBaseUrl: catalogAddonBaseForPlaying(
        catalogAddonBaseUrl: _s._catalogAddonBaseUrl,
        widgetAddonBaseUrl: widget.stremioAddonBaseUrl,
        currentProvider: _s._currentProvider,
      ),
      catalogOpen: session?.effectiveOpen,
      malId: session?.malId,
      episodeVideoId: session?.episodeVideoIdFor(epNum),
      engineCategory: session != null
          ? engineCategoryForSession(session, movie)
          : null,
      animeAudioCategory: session?.audioCategory,
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final debrid = SettingsService().debridPlaybackPrefs();
    final precheck = classifyStremioStream(
      stream,
      PlatformPlayback.capabilities,
      useDebrid: debrid.useDebrid,
      debridService: debrid.service,
    );
    // Magnets / infoHash need engine resolve - keep current video + loading
    // card, replace the player only when the new stream is ready.
    if (precheck is StremioExternalLink) {
      await handleStremioStreamIfExternal(context, stream, popToRoot: true);
      return;
    }
    if (precheck is StremioResolveFailure) {
      ForjaToast.info(precheck.message);
      return;
    }
    if (precheck == null) {
      await _switchStremioMagnetSource(stream);
      return;
    }

    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    final switchGen = ++_s._fallbackGen;
    // Fence stop/open so the error listener does not abort this switch.
    _s._isInitPlaybackRunning = true;
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    final pick = catalogPanelSelectionFromStream(stream);
    _s._markPlaybackConfirmed(false);
    _s._catalogStreamRowKey = catalogStreamRowProgressKey(stream);
    setState(() {
      _s._hasError = false;
      if (pick.catalogUrl != null && pick.catalogUrl!.isNotEmpty) {
        _s._currentPlayingCatalogUrl = pick.catalogUrl;
      }
      _s._catalogAddonBaseUrl = pick.addonBase;
      _s._catalogAddonName = pick.addonName;
      _s._catalogSourceKind = pick.kind;
      _s._currentProvider = pick.providerId;
    });
    _s._statusController.upsert(statusId, title, kind: StatusRouletteKind.loading);
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._fallbackAborted(switchGen)) {
      if (switchGen == _s._fallbackGen) _s._isInitPlaybackRunning = false;
      return;
    }

    void abortCatalogSwitch({String? message}) {
      if (!mounted || _s._disposed) return;
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      setState(() => _s._hasError = true);
      if (message != null && message.isNotEmpty) {
        debugPrint(
          '[Player] ${catalogStreamKindLabel(stream)} switch failed: $message',
        );
      }
    }

    try {
      await _s._player.stop();

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
        abortCatalogSwitch(message: msg);
        return;
      }

      await _s._configureMpvProperties();
      await resetPlayerForOpen(_s._player);
      final playPid = catalogHttpPlayProviderId(stream);
      if (!await validateStreamSourceForCheck(
        providerId: playPid,
        source: StreamSource(
          url: resolved.streamUrl,
          title: title,
          type: 'video',
          headers: resolved.headers,
        ),
        headers: resolved.headers,
      )) {
        if (!mounted || _s._fallbackAborted(switchGen)) return;
        abortCatalogSwitch(
          message: 'switch probe failed: ${resolved.streamUrl}',
        );
        return;
      }
      final openedUrl = await openCatalogHttpStreamWithPipeline(
        _s._player,
        stream: stream,
        streamUrl: resolved.streamUrl,
        headers: resolved.headers,
        providerId: playPid,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      _s._player.setVolume(_s._mpvVolume);

      if (openedUrl == null) {
        abortCatalogSwitch(
          message: 'switch failed: ${resolved.streamUrl}',
        );
        return;
      }

      setState(() {
        _s._currentUrl = resolved.streamUrl;
        _s._currentPlayingCatalogUrl = durableStreamCatalogUrl(
              catalogUrl: stream['url']?.toString(),
              playUrl: resolved.streamUrl,
            ) ??
            resolved.streamUrl;
        _s._activeMagnet = resolved.magnetLink;
        _s._hasError = false;
        _s._currentSources = null;
        final base = stream['_addonBaseUrl']?.toString();
        _s._catalogAddonBaseUrl = base;
        _s._catalogAddonName = catalogStreamAddonIdentity(stream);
        final magnet = resolved.magnetLink;
        final localTorrent = magnet != null &&
            magnet.isNotEmpty &&
            isLocalTorrentStreamUrl(resolved.streamUrl);
        _s._catalogSourceKind = localTorrent
            ? 'torrents'
            : ((base != null && base.startsWith('nuvio:'))
                ? 'nuvio'
                : (base != null && base.startsWith('engine:'))
                    ? 'engine'
                    : 'stremio');
        _s._currentProvider = catalogHttpPlayProviderId(stream);
      });
      _s._markPlaybackConfirmed(true);
      syncPlayerProgressNotifiers(
        _s._player,
        duration: _s._durationNotifier,
        position: _s._positionNotifier,
        buffered: _s._bufferedNotifier,
      );
      _s._statusController.complete();
      widget.onPlaybackStarted?.call();
      _s._startHideTimer();
    } catch (e) {
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      debugPrint('[Player] ${catalogStreamKindLabel(stream)} switch failed: $e');
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      setState(() => _s._hasError = true);
    } finally {
      if (switchGen == _s._fallbackGen) {
        _s._isInitPlaybackRunning = false;
      }
    }
  }

  /// Stremio/Torrentio magnet - same UX as [_switchTorrentSource]: keep the
  /// current player running with a bottom-right card until the new stream is
  /// ready, then open a fresh player.
  Future<void> _switchStremioMagnetSource(Map<String, dynamic> stream) async {
    // Supersede a prior episode/magnet loading card — never silent-return
    // after Sources already dismissed.
    final debrid = SettingsService().debridPlaybackPrefs();
    final useDebrid = debrid.useDebrid;
    final debridService = debrid.service;
    if (!mounted) return;
    if (!await ensureLanP2pPlayback(
      context,
      useDebrid: useDebrid,
      debridService: debridService,
    )) {
      return;
    }
    if (!mounted) return;
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    final pick = catalogPanelSelectionFromStream(stream);
    setState(() {
      if (pick.catalogUrl != null && pick.catalogUrl!.isNotEmpty) {
        _s._currentPlayingCatalogUrl = pick.catalogUrl;
      }
      _s._catalogAddonBaseUrl = pick.addonBase;
      _s._catalogAddonName = pick.addonName;
      _s._catalogSourceKind = pick.kind;
      _s._currentProvider = pick.providerId;
    });
    _s._beginEpisodeLoading(
      label: title,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      _s._setEpisodeTorrentLoading(
        initialTorrentResolveStatus(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
      );

      final resolved = await resolveStremioStream(
        stream: stream,
        profile: PlatformPlayback.capabilities,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
        onStatus: _s._setEpisodeTorrentLoading,
      );
      if (!mounted) return;
      if (resolved is! StremioPlayable || resolved.streamUrl.isEmpty) {
        final msg = resolved is StremioResolveFailure && resolved.message.isNotEmpty
            ? resolved.message
            : 'Failed to resolve stream';
        debugPrint(
          '[Player] ${catalogStreamKindLabel(stream)} switch failed: $msg',
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
      debugPrint('[Player] ${catalogStreamKindLabel(stream)} switch failed: $e');
      await _s._failEpisodeLoading('Failed to resolve stream');
    }
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    // Supersede a prior episode/magnet loading card — never silent-return
    // after Sources already dismissed.
    final debrid = SettingsService().debridPlaybackPrefs();
    final useDebrid = debrid.useDebrid;
    final debridService = debrid.service;
    if (!mounted) return;
    if (!await ensureLanP2pPlayback(
      context,
      useDebrid: useDebrid,
      debridService: debridService,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _s._activeMagnet = result.magnet;
      _s._catalogSourceKind = 'torrents';
      _s._currentProvider = 'torrent';
    });
    // Keep current video playing with the loading card while the new magnet
    // resolves in the background. Only replace the player when the stream is
    // ready - never tear down the active swarm first (that freezes mpv).
    _s._beginEpisodeLoading(
      label: result.name,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final localEngine = PlatformPlayback.capabilities.localTorrentEngine;
      _s._setEpisodeTorrentLoading(
        initialTorrentResolveStatus(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
      );

      final playback = await resolveMagnetForPlayback(
        magnet: result.magnet,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: localEngine,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
        onStatus: _s._setEpisodeTorrentLoading,
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
      debugPrint('[Player] Torrent switch failed: $e');
      await _s._failEpisodeLoading('Torrent stream failed to start');
    }
  }

  Future<void> _persistProgressForSwitch() async {
    if (widget.onSaveProgress == null) return;
    final pos = _s._positionNotifier.value;
    final dur = _s._durationNotifier.value;
    if (pos.inMilliseconds <= 0 || dur.inMilliseconds <= 0) return;
    await widget.onSaveProgress!(pos, dur);
  }

  ({String url, Map<String, String>? headers}) _externalHandoffTarget() {
    var url = _s._currentUrl ?? widget.mediaPath;
    Map<String, String>? headers = widget.headers;
    final sources = _s._currentSources;
    final idx = _s._currentFallbackSourceIndex;
    if (sources != null && idx >= 0 && idx < sources.length) {
      final source = sources[idx];
      headers = source.headers ?? headers;
      if (url.isEmpty) url = source.url;
    }
    return (url: url, headers: headers);
  }

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _persistProgressForSwitch();
    if (!mounted || !anchorContext.mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) {
        if (externalPlayer != null) {
          final target = _externalHandoffTarget();
          return handler(
            _s._positionNotifier.value,
            externalPlayer: externalPlayer,
            streamUrl: target.url,
            headers: target.headers,
            activeProvider: _s._currentProvider,
            sources: _s._currentSources,
          );
        }
        final target = _externalHandoffTarget();
        return handler(
          _s._positionNotifier.value,
          builtInEngine: builtInEngine,
          streamUrl: target.url,
          headers: target.headers,
          activeProvider: _s._currentProvider,
          sources: _s._currentSources,
        );
      },
    );
    _s._startHideTimer();
  }
}
