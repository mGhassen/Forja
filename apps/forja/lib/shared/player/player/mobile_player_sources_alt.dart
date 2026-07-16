part of 'mobile_player_screen.dart';

mixin _MobilePlayerSourcesAlt on State<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  Future<void> _showTorrentSourcesPanel() async {
    final movie = widget.movie;
    if (movie == null) return;
    _s._hideTimer?.cancel();
    PlayerSourcesPanel.show(
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
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    final switchGen = ++_s._fallbackGen;
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    _s._markPlaybackConfirmed(false);
    _s._statusController.upsert(statusId, title, kind: StatusRouletteKind.loading);
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._fallbackAborted(switchGen)) return;

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
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        if (msg.isNotEmpty) {
          debugPrint(
            '[Player] ${catalogStreamKindLabel(stream)} switch failed: $msg',
          );
        }
        return;
      }

      await _s._configureMpvProperties();
      await resetPlayerForOpen(_s._player);
      final openedUrl = await openPlayerStream(
        _s._player,
        url: resolved.streamUrl,
        headers: resolved.headers,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      _s._player.setVolume(_s._volume);

      final opened = await waitForMediaOpen(
        _s._player,
        streamUrl: openedUrl,
        timeout: isLocalTorrentStreamUrl(openedUrl)
            ? const Duration(seconds: 45)
            : const Duration(seconds: 25),
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (!opened) {
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }

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
            : ((base != null && base.startsWith('nuvio:')) ? 'nuvio' : 'stremio');
        _s._currentProvider = 'stremio_direct';
      });
      _s._markPlaybackConfirmed(true);
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
    }
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    if (_s._isLoadingNextEp) return;
    // Full reload path (same as episode switch): loading card + fresh player.
    // In-place stop/open freezes when librqbit + mpv are mid-teardown.
    _s._beginEpisodeLoading(
      label: result.name,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      TorrentStreamService().retainForExternalHandoff = false;
      final prev = _s._activeMagnet ?? widget.magnetLink;
      if (prev != null && prev.isNotEmpty) {
        TorrentStreamService().removeTorrent(prev);
      }

      final settings = SettingsService();
      final useDebrid = await settings.useDebridForStreams();
      final debridService = await settings.getDebridService();
      final localEngine = PlatformPlayback.capabilities.localTorrentEngine;
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
        localTorrentEngine: localEngine,
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
        return handler(_s._positionNotifier.value, builtInEngine: builtInEngine);
      },
    );
    _s._startHideTimer();
  }
}
