part of 'desktop_native_player_screen.dart';

mixin _DesktopNativeMenus on State<DesktopNativePlayerScreen> {
  _DesktopNativePlayerScreenState get _n =>
      this as _DesktopNativePlayerScreenState;

  String? _initialCatalogSourceKind() {
    final base = widget.stremioAddonBaseUrl;
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    if (base != null && base.startsWith('engine:')) return 'engine';
    if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) {
      return 'torrents';
    }
    final provider = widget.activeProvider;
    if (provider == 'torrent') return 'torrents';
    if (provider == 'stremio_direct') return 'stremio';
    if (provider != null && provider.startsWith('engine:')) return 'engine';
    return null;
  }

  bool get _showNextEpChip =>
      _n._hasNextEpisodeAdjacent && _n._nearEndOfEpisode && !_n._loadingNextEp;

  bool get _showSkipChip => _n._activeSkipLabel != null && !_n._skipDismissed;

  Future<void> _loadPlayerAutoPins() async {
    final settings = SettingsService();
    final autoServer = await settings.getPlayerAutoServer();
    final autoSource = await settings.getPlayerAutoSource();
    final autoAudio = await settings.getPlayerAutoAudio();
    final autoSub = await settings.getPlayerAutoSubtitle();
    if (!mounted) return;
    setState(() {
      _n._providerPinned = !autoServer;
      _n._sourcePinned = !autoSource;
      _n._audioPinned = !autoAudio;
      _n._subtitlePinned = !autoSub;
    });
  }

  Future<void> _fetchIntroDbTimestamps() async {
    if (widget.movie == null) return;
    final data = await IntroDbService().getTimestamps(
      tmdbId: widget.movie!.id,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      imdbId: widget.movie!.imdbId,
    );
    if (mounted && data != null && data.hasAnySegments) {
      setState(() => _n._introDbData = data);
    }
  }

  void _applyPlayheadChrome(Duration uiPos) {
    if (_n._disposed) return;
    if (_n._hasNextEpisodeAdjacent) {
      final nearEnd = isNearEndOfEpisode(uiPos, _n._duration);
      if (nearEnd != _n._nearEndOfEpisode) {
        setState(() {
          _n._nearEndOfEpisode = nearEnd;
          _n._onNearEndChanged(nearEnd);
        });
      }
    } else if (_n._nearEndOfEpisode) {
      setState(() {
        _n._nearEndOfEpisode = false;
        _n._onNearEndChanged(false);
      });
    }
    _n._updateActiveSkipSegment(uiPos);
  }

  void _onNearEndChanged(bool nearEnd) {
    if (!nearEnd) {
      _n._autoNextCountdown = false;
      _n._autoNextDismissed = false;
      return;
    }
    _n._autoNextCountdown =
        SettingsService.autoNextEpisodeNotifier.value && !_n._autoNextDismissed;
  }

  void _onAutoNextCountdownDone() {
    if (!mounted || !_n._autoNextCountdown) return;
    setState(() => _n._autoNextCountdown = false);
    if (!_n._showNextEpChip) return;
    unawaited(_n._nextEpisode());
  }

  void _cancelAutoNext() {
    if (!mounted) return;
    setState(() {
      _n._autoNextCountdown = false;
      _n._autoNextDismissed = true;
    });
  }

  void _updateActiveSkipSegment(Duration pos) {
    if (_n._introDbData == null) return;
    final posMs = pos.inMilliseconds;
    String? label;
    Duration? target;

    for (final seg in _n._introDbData!.recap) {
      final s = seg.startMs ?? 0;
      final e = seg.endMs;
      if (e != null && posMs >= s && posMs < e) {
        label = 'Skip Recap';
        target = Duration(milliseconds: e);
        break;
      }
    }
    if (label == null) {
      for (final seg in _n._introDbData!.intro) {
        final s = seg.startMs ?? 0;
        final e = seg.endMs;
        if (e != null && posMs >= s && posMs < e) {
          label = 'Skip Intro';
          target = Duration(milliseconds: e);
          break;
        }
      }
    }
    if (label == null) {
      for (final seg in _n._introDbData!.credits) {
        final s = seg.startMs;
        final e = seg.endMs;
        if (s != null && posMs >= s) {
          final end = e ?? _n._duration.inMilliseconds;
          if (posMs < end) {
            label = 'Skip Credits';
            target = Duration(milliseconds: end);
            break;
          }
        }
      }
    }
    if (label == null) {
      for (final seg in _n._introDbData!.preview) {
        final s = seg.startMs;
        final e = seg.endMs;
        if (s != null && posMs >= s) {
          final end = e ?? _n._duration.inMilliseconds;
          if (posMs < end) {
            label = 'Skip Preview';
            target = Duration(milliseconds: end);
            break;
          }
        }
      }
    }

    if (label != _n._activeSkipLabel) {
      setState(() {
        _n._activeSkipLabel = label;
        _n._activeSkipTarget = target;
        _n._skipDismissed = false;
      });
      final skipAuto = SettingsService.autoSkipIntroNotifier.value;
      final willAutoSkip =
          skipAuto &&
          (label == 'Skip Intro' || label == 'Skip Recap') &&
          target != null &&
          _n._autoSkipLatchedTarget != target;
      if (willAutoSkip) {
        _n._autoSkipLatchedTarget = target;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_n._activeSkipLabel != label) return;
          _n._performSkip();
        });
      }
      if (label == null) _n._autoSkipLatchedTarget = null;
    }
  }

  void _performSkip() {
    if (_n._activeSkipTarget == null) return;
    unawaited(_n._seek(_n._activeSkipTarget!));
    setState(() {
      _n._activeSkipLabel = null;
      _n._activeSkipTarget = null;
    });
  }

  Future<void> _refreshAdjacentEpisodeFlags() async {
    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      final flags = adjacentHubEpisodeFlags(
        widget.episodes,
        current,
        season: widget.selectedSeason,
      );
      if (!mounted) return;
      setState(() {
        _n._hasPrevEpisodeAdjacent = flags.hasPrev;
        _n._hasNextEpisodeAdjacent = flags.hasNext;
      });
      return;
    }

    if (widget.onNextEpisode != null) {
      if (!mounted) return;
      setState(() {
        _n._hasNextEpisodeAdjacent = widget.hasNextEpisode;
        _n._hasPrevEpisodeAdjacent = current != null && current > 1;
      });
      return;
    }

    if (widget.movie?.mediaType == 'tv' &&
        widget.selectedSeason != null &&
        widget.selectedEpisode != null) {
      final next = await _n._computeNextTmdbEpisode();
      if (!mounted) return;
      setState(() {
        _n._hasPrevEpisodeAdjacent =
            widget.selectedEpisode! > 1 || (widget.selectedSeason ?? 1) > 1;
        _n._hasNextEpisodeAdjacent = next != null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _n._hasPrevEpisodeAdjacent = false;
      _n._hasNextEpisodeAdjacent = false;
    });
  }

  Future<({int season, int episode})?> _computeNextTmdbEpisode() async {
    try {
      return await nextAiredTmdbEpisode(
        tvId: widget.movie!.id,
        season: widget.selectedSeason!,
        episode: widget.selectedEpisode!,
      );
    } catch (e) {
      debugPrint('[DesktopNative] next-episode lookup failed: $e');
      return null;
    }
  }

  Future<void> _previousEpisode() async {
    if (_n._loadingNextEp) return;
    final hub = widget.episodes;
    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (hub != null && hub.isNotEmpty && current != null) {
      final idx = hubEpisodeIndex(hub, current, season: widget.selectedSeason);
      if (idx == null || idx <= 0) return;
      final prev = hub[idx - 1];
      await _n._switchToEpisode(
        prev.season ?? widget.selectedSeason ?? 1,
        prev.number.round(),
      );
      return;
    }

    if (widget.movie?.mediaType == 'tv' &&
        widget.selectedSeason != null &&
        widget.selectedEpisode != null) {
      var season = widget.selectedSeason!;
      var episode = widget.selectedEpisode! - 1;
      if (episode < 1) {
        if (season <= 1) return;
        season -= 1;
        episode = 1;
      }
      await _n._switchToEpisode(season, episode);
    }
  }

  Future<void> _nextEpisode() async {
    if (_n._loadingNextEp) return;
    if (widget.onNextEpisode != null) {
      await _n._saveProgress();
      await widget.onNextEpisode!();
      return;
    }
    final hub = widget.episodes;
    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (hub != null && hub.isNotEmpty && current != null) {
      final idx = hubEpisodeIndex(hub, current, season: widget.selectedSeason);
      if (idx == null || idx >= hub.length - 1) return;
      final next = hub[idx + 1];
      await _n._switchToEpisode(
        next.season ?? widget.selectedSeason ?? 1,
        next.number.round(),
      );
      return;
    }
    final next = await _n._computeNextTmdbEpisode();
    if (next == null) return;
    await _n._switchToEpisode(next.season, next.episode);
  }

  Future<void> _showEpisodesMenu(BuildContext anchorContext) async {
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      PlayerPopupPanel.dismiss();
      await PlayerKitEpisodePanel.show(
        context: context,
        episodes: widget.episodes!,
        currentEpisode: widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        currentSeason: widget.selectedSeason,
        onEpisodeSelected: (ep) async {
          await _n._switchToEpisode(
            ep.season ?? widget.selectedSeason ?? 1,
            ep.number.round(),
          );
        },
        fallbackBackdropPath: widget.movie?.backdropPath,
        fallbackPosterPath: widget.movie?.posterPath,
      );
      return;
    }
    final movie = widget.movie;
    if (movie == null || movie.mediaType != 'tv') return;
    await PlayerEpisodeMenu.show(
      context,
      movie: movie,
      currentSeason: widget.selectedSeason ?? 1,
      currentEpisode: widget.selectedEpisode ?? 1,
      onEpisodeSelected: _n._switchToEpisode,
      anchorContext: anchorContext,
    );
  }

  Future<void> _switchToEpisode(int season, int episode) async {
    if (widget.movie == null) return;
    if (season == widget.selectedSeason && episode == widget.selectedEpisode) {
      return;
    }
    if (isEnginePlayerSession(widget.activeProvider)) {
      await _n._saveProgress();
      if (!mounted) return;
      setState(() => _n._loadingNextEp = true);
      try {
        if (_n._av) {
          await AvPlayerBridge.pause(_n._viewId);
        } else {
          await VlcPlayerBridge.pause(_n._viewId);
        }
      } catch (_) {}
      if (!mounted) return;
      try {
        await switchEpisodeViaEngineAutoPlay(
          context: context,
          movie: widget.movie!,
          season: season,
          episode: episode,
          stremioId: widget.stremioId,
          session: widget.enginePlaySession,
          episodes: widget.episodes,
          preferredPluginId: EngineIds.pluginIdFromChip(
            _n._currentProvider ?? widget.activeProvider ?? '',
          ),
        );
      } finally {
        if (mounted) setState(() => _n._loadingNextEp = false);
      }
      return;
    }

    setState(() => _n._loadingNextEp = true);
    try {
      await _n._saveProgress();
      final chain = episodeProviderChain(
        providers: widget.providers,
        activeProvider: widget.activeProvider,
        currentProvider: _n._currentProvider ?? widget.activeProvider,
        magnetLink: widget.magnetLink,
      );
      if (chain.isEmpty) {
        throw Exception('No provider available for S${season}E$episode');
      }

      EpisodeSwitchResult? resolved;
      for (final key in chain) {
        if (!mounted) return;
        resolved = await resolveEpisodeForProvider(
          providerKey: key,
          movie: widget.movie!,
          season: season,
          episode: episode,
          providers: widget.providers,
          magnetLink: widget.magnetLink,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          torrentEp: metaOpenTorrentEp(widget.enginePlaySession?.effectiveOpen),
        );
        if (resolved != null) break;
      }
      if (resolved == null || resolved.streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${season}E$episode');
      }
      if (!mounted) return;

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      final catalog = isCatalogSourcesMode(resolved.activeProvider);
      unawaited(
        AppRouter.openPlayer(
          context,
          streamUrl: resolved.streamUrl,
          title: nextTitle,
          headers: catalog ? null : resolved.headers,
          movie: widget.movie,
          selectedSeason: season,
          selectedEpisode: episode,
          magnetLink: resolved.magnetLink,
          fileIndex: resolved.fileIndex,
          activeProvider: resolved.activeProvider,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          providers: catalog ? null : widget.providers,
          sources: catalog ? null : resolved.sources,
          enginePlaySession: widget.enginePlaySession,
          episodes: widget.episodes,
          hubEpisodeNumber: widget.episodes != null ? episode : null,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          onSaveProgress: widget.onSaveProgress,
        ),
      );
    } catch (e) {
      debugPrint('[DesktopNative] episode switch failed: $e');
      if (mounted) {
        ForjaToast.error(context.l10n.playerSourceOpenEpisodeFailed);
        setState(() => _n._loadingNextEp = false);
      }
    }
  }

  void _showCastPicker() {
    showPlayerCastPicker(
      context,
      streamUrl: _n._url.isNotEmpty ? _n._url : widget.mediaPath,
      title: widget.title,
      headers: _n._headers ?? widget.headers,
      statusController: _n._statusController,
      position: _n._position,
      duration: _n._duration,
      handoff: CastHandoff(
        onStarted: () {
          unawaited(() async {
            if (_n._av) {
              await AvPlayerBridge.pause(_n._viewId);
            } else {
              await VlcPlayerBridge.pause(_n._viewId);
            }
          }());
        },
        onEnded: (resumeAt) async {
          if (_n._disposed || !mounted) return;
          if (resumeAt > Duration.zero) await _n._seek(resumeAt);
          if (_n._av) {
            await AvPlayerBridge.play(_n._viewId);
          } else {
            await VlcPlayerBridge.play(_n._viewId);
          }
        },
        onPosition: (pos) {
          if (_n._disposed || !mounted) return;
          setState(() => _n._position = pos);
          _n._applyPlayheadChrome(pos);
        },
        onPlaying: (playing) {
          if (_n._disposed || !mounted) return;
          setState(() => _n._playing = playing);
        },
      ),
    );
    _n._bumpControls();
  }

  Future<void> _remountPlayable({
    required String url,
    Map<String, String>? headers,
    String? providerId,
    List<StreamSource>? sources,
    BuiltInPlayerEngine? engine,
  }) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _n._saveProgress();
    if (!mounted) return;
    final target = engine ?? widget.builtInEngine;
    final torrent =
        isLocalTorrentStreamUrl(url) || url.toLowerCase().startsWith('magnet:');
    if (torrent && target != BuiltInPlayerEngine.mediaKit) {
      ForjaToast.info(context.l10n.playerScreenTorrentsNeedMediaKit);
      await handler(
        _n._position,
        builtInEngine: BuiltInPlayerEngine.mediaKit,
        streamUrl: url,
        headers: headers,
        activeProvider: providerId,
        sources: sources,
      );
      return;
    }
    await handler(
      _n._position,
      builtInEngine: target,
      streamUrl: url,
      headers: headers,
      activeProvider: providerId,
      sources: sources,
    );
  }

  Future<void> _showTorrentSourcesPanel() async {
    final movie = widget.movie;
    if (movie == null) return;
    _n._hideControlsTimer?.cancel();
    final session = widget.enginePlaySession;
    final ep = widget.selectedEpisode;
    final epNum = ep ?? 1;
    await PlayerSourcesPanel.show(
      context: context,
      movie: movie,
      season: widget.selectedSeason,
      episode: ep,
      currentMagnet: _n._activeMagnet ?? widget.magnetLink,
      currentStreamUrl: _n._url.isNotEmpty ? _n._url : widget.mediaPath,
      currentPlayingCatalogUrl:
          _n._currentPlayingCatalogUrl ??
          durableStreamCatalogUrl(
            playUrl: _n._url.isNotEmpty ? _n._url : widget.mediaPath,
          ),
      currentPlayingRowKey: _n._catalogStreamRowKey,
      playbackConfirmed: _n._playbackStartedNotified,
      preferredKind: _n._catalogSourceKind,
      currentAddonBaseUrl: catalogAddonBaseForPlaying(
        catalogAddonBaseUrl: _n._catalogAddonBaseUrl,
        widgetAddonBaseUrl: widget.stremioAddonBaseUrl,
        currentProvider: _n._currentProvider,
      ),
      open: session?.effectiveOpen,
      meta: session?.meta,
      malId: session?.malId,
      episodeVideoId: session?.episodeVideoIdFor(epNum),
      pluginId: session?.pluginId,
      engineCategory: session != null
          ? engineCategoryForSession(session, movie)
          : null,
      animeAudioCategory: session?.audioCategory,
      onTorrentSelected: (result) async {
        ForjaToast.info(context.l10n.playerScreenTorrentsNeedMediaKit);
        await _n._remountPlayable(
          url: result.magnet,
          providerId: 'torrent',
          engine: BuiltInPlayerEngine.mediaKit,
        );
      },
      onStremioSelected: _n._switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final precheck = classifyStremioStream(
      stream,
      PlatformPlayback.capabilities,
    );
    if (precheck is StremioExternalLink) {
      await handleStremioStreamIfExternal(context, stream, popToRoot: true);
      return;
    }
    if (precheck is StremioResolveFailure) {
      ForjaToast.info(precheck.message);
      return;
    }
    if (streamDrmBlockedOffAndroid(stream['drm'])) {
      ForjaToast.info(kStreamDrmAndroidOnlyMessage);
      return;
    }
    if (precheck == null) {
      ForjaToast.info(context.l10n.playerScreenTorrentsNeedMediaKit);
      final magnet =
          stream['infoHash']?.toString() ?? stream['url']?.toString() ?? '';
      if (magnet.isNotEmpty) {
        await _n._remountPlayable(
          url: magnet.startsWith('magnet:')
              ? magnet
              : 'magnet:?xt=urn:btih:$magnet',
          providerId: catalogHttpPlayProviderId(stream),
          engine: BuiltInPlayerEngine.mediaKit,
        );
      }
      return;
    }

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: PlatformPlayback.capabilities,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted) return;
    if (resolved is! StremioPlayable) {
      final msg = resolved is StremioResolveFailure
          ? resolved.message
          : context.l10n.playerScreenFailedToResolveStream;
      ForjaToast.info(msg);
      return;
    }
    final pid = catalogHttpPlayProviderId(stream);
    await _n._remountPlayable(
      url: resolved.streamUrl,
      headers: resolvePlaybackHttpHeaders(
        resolved.headers,
        streamUrl: resolved.streamUrl,
        providerId: pid,
      ),
      providerId: pid,
    );
  }

  void _showStreamMenu([BuildContext? anchorContext]) {
    if (!_n._hasStreamPicker) return;
    PlayerStreamMenu.show(
      context,
      providers: widget.providers,
      providerSourcesCache: _n._liveProviderSourcesCache,
      providerLoadFailures: _n._providerLoadFailures,
      providerProbesNotifier: widget.providerProbesNotifier,
      statusController: _n._statusController,
      readState: () => PlayerStreamMenuState(
        currentProviderId: _n._currentProvider ?? widget.activeProvider,
        sources: _n._currentSources,
        currentUrl: _n._url.isNotEmpty ? _n._url : widget.mediaPath,
        currentPlayingCatalogUrl: _n._currentPlayingCatalogUrl,
        current111477FileUrl: null,
        is111477:
            (_n._currentProvider ?? widget.activeProvider) == 'service111477',
        playbackConfirmed: _n._playbackStartedNotified,
        mediaPlaying: _n._playing,
      ),
      onLoadProvider: (providerId, {forceRefresh = false}) =>
          _n._loadServer(providerId, forceRefresh: forceRefresh),
      onSelectProvider: (providerId) async {
        setState(() {
          _n._currentProvider = providerId;
          _n._providerPinned = true;
        });
        unawaited(SettingsService().setPlayerAutoServer(false));
        final sources = await _n._loadServer(providerId);
        if ((sources == null || sources.isEmpty) && mounted) {
          ForjaToast.warning(
            PlayerProviderMenu.unavailableMessage(
              providerId,
              widget.providers?[providerId],
            ),
            duration: const Duration(seconds: 2),
          );
        }
        _n._streamMenuRefreshTick.value++;
        return sources;
      },
      onSelectSource: (source, index) async {
        final pid =
            source.providerId ??
            _n._currentProvider ??
            widget.activeProvider ??
            '';
        await _n._remountPlayable(
          url: source.url,
          headers: source.headers ?? widget.headers,
          providerId: pid.isEmpty ? null : pid,
          sources: _n._currentSources,
        );
        _n._streamMenuRefreshTick.value++;
      },
      onCheckSource: (source, index, [providerId]) async {
        try {
          return await probeStreamSourceUrl(
            source.url,
            source.headers ?? widget.headers,
            probe: source.probe,
          );
        } catch (_) {
          return false;
        }
      },
      onTogglePlayPause: () => unawaited(_n._playPause()),
      anchorContext: anchorContext,
      refreshListenable: _n._streamMenuRefreshTick,
      movie: widget.movie,
      selectedSeason: widget.selectedSeason,
      selectedEpisode: widget.selectedEpisode,
      hubEpisodeNumber: widget.hubEpisodeNumber,
      activeProvider: widget.activeProvider,
    );
    _n._bumpControls();
  }

  Future<List<StreamSource>?> _loadServer(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _n._liveProviderSourcesCache.value[providerId];
      if (cached != null && cached.isNotEmpty) return cached;
      if (providerId == _n._currentProvider &&
          _n._currentSources != null &&
          _n._currentSources!.isNotEmpty) {
        return _n._currentSources;
      }
    } else {
      final next = Map<String, List<StreamSource>>.from(
        _n._liveProviderSourcesCache.value,
      )..remove(providerId);
      _n._liveProviderSourcesCache.value = next;
    }

    for (final id in _n._providerLoadGens.keys.toList()) {
      if (id == providerId) continue;
      _n._providerLoadGens[id] = (_n._providerLoadGens[id] ?? 0) + 1;
    }

    final gen = (_n._providerLoadGens[providerId] ?? 0) + 1;
    _n._providerLoadGens[providerId] = gen;

    try {
      if (widget.movie == null || widget.providers == null) return null;
      final hit = await PlayerSourceResolve.resolvePinnedForMovie(
        movie: widget.movie!,
        providers: widget.providers!,
        providerId: providerId,
        season: widget.selectedSeason ?? 1,
        episode:
            widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1,
        isCancelled: () =>
            _n._disposed || (_n._providerLoadGens[providerId] ?? 0) != gen,
        bypassDiskCache: forceRefresh,
      );
      if (_n._disposed || (_n._providerLoadGens[providerId] ?? 0) != gen) {
        return null;
      }
      if (hit != null && hit.streamSources.isNotEmpty) {
        final sources = sourcesOwnedByProvider(
          providerId,
          dedupeStreamSources(hit.streamSources),
        );
        if (sources.isEmpty) {
          _n._markProviderLoadFailed(providerId);
          return null;
        }
        if (_n._providerLoadFailures.value.contains(providerId)) {
          final next = {..._n._providerLoadFailures.value}..remove(providerId);
          _n._providerLoadFailures.value = next;
        }
        _n._liveProviderSourcesCache.value = {
          ..._n._liveProviderSourcesCache.value,
          providerId: sources,
        };
        if (providerId == _n._currentProvider) {
          _n._currentSources = sources;
        }
        _n._streamMenuRefreshTick.value++;
        return sources;
      }
      _n._markProviderLoadFailed(providerId);
      return null;
    } catch (_) {
      _n._markProviderLoadFailed(providerId);
      return null;
    }
  }

  void _markProviderLoadFailed(String providerId) {
    if (_n._disposed || providerId.isEmpty) return;
    if (_n._providerLoadFailures.value.contains(providerId)) return;
    _n._providerLoadFailures.value = {
      ..._n._providerLoadFailures.value,
      providerId,
    };
    _n._streamMenuRefreshTick.value++;
  }

  void _showSettingsMenu(BuildContext anchorContext) {
    final hasProviders =
        widget.providers != null &&
        widget.providers!.isNotEmpty &&
        widget.movie != null &&
        !_n._usesCatalogSourcesPanel;
    final hasSources =
        _n._currentSources != null && _n._currentSources!.isNotEmpty;

    String fitLabel() {
      return switch (_n._videoFit) {
        BoxFit.cover => 'CROP',
        BoxFit.fill => 'FILL',
        _ => 'FIT',
      };
    }

    List<PlayerSettingsEntry> buildEntries() {
      return [
        PlayerSettingsEntry(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.playerScreenAutoSelection,
          subtitle: context.l10n.playerScreenAutoSelectionSubtitle,
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) => Column(
              children: [
                if (hasProviders) ...[
                  PlayerPopupToggleRow(
                    label: context.l10n.playerScreenAutoServer,
                    value: !_n._providerPinned,
                    onChanged: (on) async {
                      final settings = SettingsService();
                      if (on) {
                        await settings.setPlayerAutoServer(true);
                        setState(() => _n._providerPinned = false);
                      } else {
                        await settings.setPlayerAutoServer(false);
                        setState(() => _n._providerPinned = true);
                      }
                      setPage(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasSources) ...[
                  PlayerPopupToggleRow(
                    label: context.l10n.playerScreenAutoSource,
                    value: !_n._sourcePinned,
                    onChanged: (on) async {
                      final settings = SettingsService();
                      if (on) {
                        await settings.setPlayerAutoSource(true);
                        setState(() => _n._sourcePinned = false);
                      } else {
                        await settings.setPlayerAutoSource(false);
                        setState(() => _n._sourcePinned = true);
                      }
                      setPage(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                PlayerPopupToggleRow(
                  label: context.l10n.playerScreenAutoAudio,
                  value: !_n._audioPinned,
                  onChanged: (on) async {
                    final notice =
                        context.l10n.playerScreenAutoAudioNeedsMediaKitOrExo;
                    final settings = SettingsService();
                    if (on) {
                      await settings.setPlayerAutoAudio(true);
                      setState(() => _n._audioPinned = false);
                    } else {
                      await settings.setPlayerAutoAudio(false);
                      setState(() => _n._audioPinned = true);
                    }
                    setPage(() {});
                    ForjaToast.info(notice);
                  },
                ),
                const SizedBox(height: 12),
                PlayerPopupToggleRow(
                  label: context.l10n.playerScreenAutoSubtitles,
                  value: !_n._subtitlePinned,
                  onChanged: (on) async {
                    final notice =
                        context.l10n.playerScreenAutoSubtitlesNeedMediaKitOrExo;
                    final settings = SettingsService();
                    if (on) {
                      await settings.setPlayerAutoSubtitle(true);
                      setState(() => _n._subtitlePinned = false);
                    } else {
                      await settings.setPlayerAutoSubtitle(false);
                      setState(() => _n._subtitlePinned = true);
                    }
                    setPage(() {});
                    ForjaToast.info(notice);
                  },
                ),
                const SizedBox(height: 12),
                PlayerPopupToggleRow(
                  label: context.l10n.playerScreenAutoSkipIntro,
                  value: SettingsService.autoSkipIntroNotifier.value,
                  onChanged: (on) async {
                    await SettingsService().setAutoSkipIntro(on);
                    schedulePreferencesSyncPush();
                    setPage(() {});
                  },
                ),
                const SizedBox(height: 12),
                PlayerPopupToggleRow(
                  label: context.l10n.playerScreenAutoNextEpisode,
                  value: SettingsService.autoNextEpisodeNotifier.value,
                  onChanged: (on) async {
                    await SettingsService().setAutoNextEpisode(on);
                    schedulePreferencesSyncPush();
                    setPage(() {});
                  },
                ),
              ],
            ),
          ),
        ),
        PlayerSettingsEntry(
          icon: Icons.aspect_ratio_rounded,
          title: context.l10n.playerScreenAspectRatio,
          subtitle: context.l10n.playerScreenAspectRatioSubtitle,
          value: fitLabel(),
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) => playerPopupChipRow([
              for (final entry in const [
                (BoxFit.contain, 'FIT'),
                (BoxFit.cover, 'CROP'),
                (BoxFit.fill, 'FILL'),
              ])
                PlayerPopupOptionChip(
                  label: entry.$2,
                  selected: _n._videoFit == entry.$1,
                  expanded: true,
                  grouped: true,
                  onTap: () {
                    setState(() => _n._videoFit = entry.$1);
                    setPage(() {});
                  },
                ),
            ]),
          ),
        ),
      ];
    }

    showPlayerSettingsMenu(
      context: context,
      anchorContext: anchorContext,
      buildEntries: buildEntries,
    );
  }
}
