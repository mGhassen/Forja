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
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    _s._playbackConfirmed = false;
    _s._statusController.upsert(statusId, title, kind: StatusRouletteKind.loading);
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _s._player.stop();

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
          : 'Failed to resolve stream';
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception(msg);
    }

    await _s._configureMpvProperties();
    await resetPlayerForOpen(_s._player);
    await _s._player.open(
      Media(resolved.streamUrl, httpHeaders: resolved.headers),
    );
    _s._player.setVolume(_s._volume);

    final opened = await waitForMediaOpen(
      _s._player,
      streamUrl: resolved.streamUrl,
      timeout: isLocalTorrentStreamUrl(resolved.streamUrl)
          ? const Duration(seconds: 45)
          : const Duration(seconds: 12),
    );
    if (!mounted) return;
    if (!opened) {
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Stream failed to open');
    }

    setState(() {
      _s._currentUrl = resolved.streamUrl;
      _s._activeMagnet = resolved.magnetLink;
      _s._hasError = false;
      _s._errorMessage = '';
      _s._currentSources = null;
    });
    _s._playbackConfirmed = true;
    _s._statusController.complete();
    widget.onPlaybackStarted?.call();
    _s._startHideTimer();
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-torrent-${result.magnet.hashCode}';
    _s._playbackConfirmed = false;
    _s._statusController.upsert(
      statusId,
      result.name,
      kind: StatusRouletteKind.loading,
    );
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _s._player.stop();

    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    final debridService = await settings.getDebridService();
    final localEngine = PlatformPlayback.capabilities.localTorrentEngine;

    final playback = await resolveMagnetForPlayback(
      magnet: result.magnet,
      useDebrid: useDebrid,
      debridService: debridService,
      localTorrentEngine: localEngine,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted) return;
    if (playback == null) {
      _s._statusController.upsert(
        statusId,
        result.name,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Failed to resolve torrent');
    }

    await _s._configureMpvProperties();
    await resetPlayerForOpen(_s._player);
    await _s._player.open(Media(playback.url));
    _s._player.setVolume(_s._volume);

    final opened = await waitForMediaOpen(
      _s._player,
      streamUrl: playback.url,
      timeout: const Duration(seconds: 45),
    );
    if (!mounted) return;
    if (!opened) {
      _s._statusController.upsert(
        statusId,
        result.name,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Torrent failed to open');
    }

    setState(() {
      _s._currentUrl = playback.url;
      _s._activeMagnet = result.magnet;
      _s._hasError = false;
      _s._errorMessage = '';
      _s._currentSources = null;
    });
    _s._playbackConfirmed = true;
    _s._statusController.complete();
    widget.onPlaybackStarted?.call();
    _s._startHideTimer();
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
    if (!mounted) return;
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
