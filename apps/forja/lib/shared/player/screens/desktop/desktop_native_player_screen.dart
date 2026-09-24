import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/store/list_follow_from_watched.dart';
import 'package:forja/shared/player/avplayer/av_player_bridge.dart';
import 'package:forja/shared/player/avplayer/av_player_view.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/chrome/player_seek_scrub_cancel.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/controls/menus/player_app_menu.dart';
import 'package:forja/shared/player/controls/seek/seek_bar_with_preview.dart';
import 'package:forja/shared/player/controls/seek/seek_bar_zones.dart';
import 'package:forja/shared/playback/probe/playback_stream_guards.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/downloads/download_enqueue.dart';
import 'package:forja/shared/player/vlc/vlc_player_bridge.dart';
import 'package:forja/shared/player/vlc/vlc_player_view.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/playback/loading_overlay.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shell/desktop/desktop_window_geometry.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:rust/rust.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Catalog VOD on desktop via AVPlayer (macOS) or libVLC (macOS / Windows).
///
/// Thin sibling of [ExoPlayerScreen] — not a MediaKit [DesktopPlayerScreen] fork.
class DesktopNativePlayerScreen extends StatefulWidget {
  const DesktopNativePlayerScreen({
    super.key,
    required this.mediaPath,
    required this.title,
    required this.builtInEngine,
    this.headers,
    this.movie,
    this.selectedSeason,
    this.selectedEpisode,
    this.activeProvider,
    this.startPosition,
    this.sources,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.episodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.enginePlaySession,
    this.onSaveProgress,
    this.onPlaybackStarted,
    this.onSwitchPlayer,
  });

  final String mediaPath;
  final String title;
  final BuiltInPlayerEngine builtInEngine;
  final Map<String, String>? headers;
  final Movie? movie;
  final int? selectedSeason;
  final int? selectedEpisode;
  final String? activeProvider;
  final Duration? startPosition;
  final List<StreamSource>? sources;
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;
  final List<PlayerKitEpisode>? episodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerKitEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;
  final EnginePlaySession? enginePlaySession;
  final Future<void> Function(Duration position, Duration duration, {String? sourceId, String? streamUrl})?
      onSaveProgress;
  final VoidCallback? onPlaybackStarted;
  final PlayerSwitchHandler? onSwitchPlayer;

  @override
  State<DesktopNativePlayerScreen> createState() =>
      _DesktopNativePlayerScreenState();
}

class _DesktopNativePlayerScreenState extends State<DesktopNativePlayerScreen> {
  static int _nextViewId = 1;

  late final int _viewId = _nextViewId++;
  int? _vlcTextureId;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;
  Timer? _progressSaveTimer;
  Timer? _hideControlsTimer;

  String _url = '';
  Map<String, String>? _headers;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  bool _ready = false;
  bool _controlsVisible = true;
  bool _disposed = false;
  bool _seeking = false;
  bool _resumeApplied = false;
  bool _playbackStartedNotified = false;
  bool _escapeArmed = false;
  bool _failoverToMediaKitUsed = false;
  double _volume = 100;

  bool get _av => widget.builtInEngine == BuiltInPlayerEngine.avPlayer;
  bool get _vlc => widget.builtInEngine == BuiltInPlayerEngine.vlc;

  @override
  void initState() {
    super.initState();
    _url = widget.mediaPath;
    _headers = widget.headers;
    _position = widget.startPosition ?? Duration.zero;
    unawaited(_boot());
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_disposed && _playing) unawaited(_saveProgress());
    });
    _scheduleHideControls();
  }

  Future<void> _boot() async {
    if (_vlc) {
      _vlcTextureId = await VlcPlayerBridge.create(_viewId);
      if (_disposed) return;
      _eventSub = VlcPlayerBridge.eventsFor(_viewId).listen(_onEvent);
    } else {
      _eventSub = AvPlayerBridge.eventsFor(_viewId).listen(_onEvent);
    }
    if (mounted) setState(() => _ready = true);
    await Future<void>.delayed(Duration.zero);
    if (_disposed || !mounted) return;
    await _openCurrent();
  }

  Future<void> _openCurrent() async {
    setState(() {
      _buffering = true;
      _resumeApplied = false;
    });
    try {
      final prepared = await _prepareOpenTarget();
      _url = prepared.url;
      _headers = prepared.headers;
      debugPrint(
        '[DesktopNative] open ${_av ? 'AVPlayer' : 'VLC'} '
        'url=${_shortUrl(_url)} headers=${_headers?.length ?? 0}'
        '${_headers == null || _headers!.isEmpty ? '' : ' keys=${_headers!.keys.join(',')}'}',
      );
      if (_av) {
        await AvPlayerBridge.open(
          viewId: _viewId,
          url: _url,
          headers: _headers,
        );
      } else {
        await VlcPlayerBridge.open(
          viewId: _viewId,
          url: _url,
          headers: _headers,
        );
      }
      final resume = widget.startPosition ?? Duration.zero;
      if (resume > Duration.zero) {
        await _seek(resume);
      }
    } catch (e) {
      debugPrint('[DesktopNative] open failed: $e');
      await _failoverToMediaKit('open failed: $e');
    }
  }

  /// Same header / proxy prep as MediaKit [openPlayerStream] (mwVault strip, etc.).
  Future<({String url, Map<String, String>? headers})> _prepareOpenTarget()
      async {
    var openUrl = normalizePlaybackStreamUrl(widget.mediaPath);
    final rawHeaders = widget.headers ?? const <String, String>{};
    final proxied1shows = await proxy1showsHlsIfNeeded(
      streamUrl: openUrl,
      headers: rawHeaders,
      providerId: widget.activeProvider,
    );
    openUrl = proxied1shows.url;
    final proxiedExt = await proxyExtensionlessHlsIfNeeded(
      streamUrl: openUrl,
      headers: proxied1shows.headers.isEmpty
          ? rawHeaders
          : proxied1shows.headers,
      providerId: widget.activeProvider,
    );
    openUrl = proxiedExt.url;
    final catalogForHeaders = hlsProxyTargetUrl(openUrl) ?? openUrl;
    final mwVaultProxy = isMwVaultProxyPlayUrl(openUrl);
    final hdrs =
        (isLocalLoopbackPlayUrl(openUrl) &&
            (is1showsCdnStreamUrl(catalogForHeaders) ||
                shouldProxyExtensionlessHls(catalogForHeaders)))
        ? const <String, String>{}
        : resolvePlaybackHttpHeaders(
            widget.headers,
            streamUrl: catalogForHeaders,
            providerId: widget.activeProvider,
          );
    final isRemoteHttp =
        (openUrl.startsWith('http://') || openUrl.startsWith('https://')) &&
        !isLocalTorrentStreamUrl(openUrl) &&
        !isLocalLoopbackPlayUrl(openUrl);
    final attachHeaders =
        !mwVaultProxy && hdrs.isNotEmpty && isRemoteHttp;
    return (
      url: openUrl,
      headers: attachHeaders ? hdrs : null,
    );
  }

  String _shortUrl(String url) {
    if (url.length <= 96) return url;
    return '${url.substring(0, 96)}…';
  }

  Future<void> _failoverToMediaKit(String reason) async {
    if (_failoverToMediaKitUsed || _disposed) return;
    final handler = widget.onSwitchPlayer;
    if (handler == null) {
      if (mounted) ForjaToast.error('Could not open stream');
      return;
    }
    _failoverToMediaKitUsed = true;
    debugPrint('[DesktopNative] failover → MediaKit ($reason)');
    if (mounted) ForjaToast.info('Switching to MediaKit…');
    await handler(
      _position,
      builtInEngine: BuiltInPlayerEngine.mediaKit,
      streamUrl: _url.isNotEmpty ? _url : widget.mediaPath,
      headers: _headers ?? widget.headers,
      activeProvider: widget.activeProvider,
      sources: widget.sources,
    );
  }

  void _onEvent(Map<dynamic, dynamic> event) {
    if (_disposed || !mounted) return;
    final type = event['type']?.toString() ?? '';
    switch (type) {
      case 'ready':
        setState(() => _buffering = false);
        if (!_resumeApplied) {
          final resume = widget.startPosition ?? Duration.zero;
          if (resume > Duration.zero) {
            _resumeApplied = true;
            unawaited(_seek(resume));
          } else {
            _resumeApplied = true;
          }
        }
        break;
      case 'playing':
        final playing = event['value'] == true;
        setState(() {
          _playing = playing;
          if (playing) _buffering = false;
        });
        if (playing) {
          unawaited(WakelockPlus.enable());
          if (!_playbackStartedNotified) {
            _playbackStartedNotified = true;
            widget.onPlaybackStarted?.call();
          }
        }
        break;
      case 'buffering':
        final buffering = event['value'] == true;
        if (buffering != _buffering) {
          setState(() => _buffering = buffering);
        }
        break;
      case 'progress':
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        final durMs = (event['duration'] as num?)?.toInt() ?? 0;
        final bufMs = (event['buffered'] as num?)?.toInt() ?? 0;
        final pos = Duration(milliseconds: posMs);
        if (_seeking) return;
        setState(() {
          _position = pos;
          if (durMs > 0) _duration = Duration(milliseconds: durMs);
          if (bufMs > 0) _buffered = Duration(milliseconds: bufMs);
        });
        break;
      case 'error':
        final msg = event['value']?.toString() ?? 'playback error';
        debugPrint('[DesktopNative] error: $msg');
        unawaited(_failoverToMediaKit(msg));
        break;
    }
  }

  Future<void> _playPause() async {
    if (_playing) {
      if (_av) {
        await AvPlayerBridge.pause(_viewId);
      } else {
        await VlcPlayerBridge.pause(_viewId);
      }
    } else {
      if (_av) {
        await AvPlayerBridge.play(_viewId);
      } else {
        await VlcPlayerBridge.play(_viewId);
      }
    }
    _bumpControls();
  }

  Future<void> _seek(Duration target) async {
    var t = target;
    if (_duration > Duration.zero && t > _duration) t = _duration;
    if (t < Duration.zero) t = Duration.zero;
    setState(() {
      _seeking = true;
      _position = t;
    });
    try {
      if (_av) {
        await AvPlayerBridge.seek(_viewId, t);
      } else {
        await VlcPlayerBridge.seek(_viewId, t);
      }
    } finally {
      if (mounted) setState(() => _seeking = false);
    }
    _bumpControls();
  }

  Future<void> _saveProgress() async {
    if (_duration.inMilliseconds <= 0) return;
    final playUrl = _url.isNotEmpty ? _url : widget.mediaPath;
    final durableUrl = durableStreamCatalogUrl(playUrl: playUrl);
    if (widget.onSaveProgress != null) {
      await widget.onSaveProgress!(
        _position,
        _duration,
        sourceId: widget.activeProvider,
        streamUrl: durableUrl ?? playUrl,
      );
      return;
    }
    final movie = widget.movie;
    if (movie == null) return;
    final provider = widget.activeProvider;
    await WatchHistoryService().saveProgress(
      tmdbId: movie.id,
      imdbId: movie.imdbId,
      title: widget.title,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      method: provider != null && provider != 'amri' ? 'stream' : 'amri',
      sourceId: provider ?? _url,
      position: _position.inMilliseconds,
      duration: _duration.inMilliseconds,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      streamUrl: durableUrl,
      mediaType: movie.mediaType,
    );
    if (movie.mediaType == 'movie') {
      unawaited(
        ListFollowFromWatched.markMovieCompletedIfFinished(
          movie,
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds,
        ),
      );
    }
  }

  void _bumpControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed && mounted && _playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _enqueueCurrentDownload() async {
    final url = (_url.isNotEmpty ? _url : widget.mediaPath).trim();
    await enqueuePlayerCurrentDownload(
      context: context,
      url: url,
      headers: widget.headers,
      movie: widget.movie,
      fallbackTitle: widget.title,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      sourceName: widget.activeProvider ?? 'Stream',
      providerId: widget.activeProvider,
    );
  }

  Future<void> _exit() async {
    await _saveProgress();
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    dismissActiveLoadingOverlayRoute(navigator);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _showPlayerMenu(BuildContext anchor) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _saveProgress();
    if (!mounted || !anchor.mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchor,
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      surface: BuiltInPlayerMenuSurface.catalogVod,
      streamUrl: _url,
      torrentLocalhost: isLocalTorrentStreamUrl(_url),
      separateAudioUrl: false,
      onSelect: ({builtInEngine, externalPlayer}) async {
        if (_av) {
          try {
            await AvPlayerBridge.pause(_viewId);
          } catch (_) {}
        } else {
          try {
            await VlcPlayerBridge.pause(_viewId);
          } catch (_) {}
        }
        await handler(
          _position,
          builtInEngine: builtInEngine,
          externalPlayer: externalPlayer,
          streamUrl: _url,
          headers: _headers,
          activeProvider: widget.activeProvider,
          sources: widget.sources,
        );
      },
    );
    _bumpControls();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      unawaited(_playPause());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seek(_position - const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seek(_position + const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
        _escapeArmed = false;
        return KeyEventResult.handled;
      }
      if (!_escapeArmed) {
        _escapeArmed = true;
        ForjaToast.info('Press Esc again to exit');
        return KeyEventResult.handled;
      }
      unawaited(_exit());
      return KeyEventResult.handled;
    }
    _bumpControls();
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSaveTimer?.cancel();
    _hideControlsTimer?.cancel();
    unawaited(_eventSub?.cancel());
    unawaited(WakelockPlus.disable());
    if (_av) {
      unawaited(AvPlayerBridge.dispose(_viewId));
    } else {
      unawaited(VlcPlayerBridge.dispose(_viewId));
    }
    DesktopWindowGeometry.abandonPlayerSession();
    super.dispose();
  }

  Future<void> _setVolume(double uiVolume) async {
    final v = uiVolume.clamp(0.0, 100.0);
    setState(() => _volume = v);
    final norm = v / 100.0;
    if (_av) {
      await AvPlayerBridge.setVolume(_viewId, norm);
    } else {
      await VlcPlayerBridge.setVolume(_viewId, norm);
    }
    _bumpControls();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _bumpControls(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              if (_ready)
                Positioned.fill(
                  child: _av
                      ? AvPlayerView(viewId: _viewId)
                      : VlcPlayerView(
                          viewId: _viewId,
                          textureId: _vlcTextureId,
                        ),
                ),
              if (!_ready || _buffering)
                const Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.brandGreen,
                  ),
                ),
              if (_controlsVisible) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => unawaited(_playPause()),
                    child: const SizedBox.expand(),
                  ),
                ),
                DesktopWindowChrome.overlayDragStrip(),
                _buildChrome(compact: compact),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Same shared chrome widgets as MediaKit [DesktopPlayerScreen] / Exo desktop.
  Widget _buildChrome({required bool compact}) {
    final topBarHeight = PlayerTopBar.totalHeight(context);
    final showCenter = !_buffering;
    final showPausedHero = widget.movie != null && (!_playing || _buffering);

    return Positioned.fill(
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PlayerOverlayGradient(isTop: true),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PlayerOverlayGradient(isTop: false),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PlayerTopBar(
              title: widget.title,
              season: widget.episodes != null ? null : widget.selectedSeason,
              episode: widget.episodes != null ? null : widget.selectedEpisode,
              onBack: () => unawaited(_exit()),
              trailing: PlayerTopBarActions(
                showPlayer: widget.onSwitchPlayer != null,
                onPlayer: widget.onSwitchPlayer != null
                    ? (anchor) => unawaited(_showPlayerMenu(anchor))
                    : null,
                showDownload: true,
                onDownload: () => unawaited(_enqueueCurrentDownload()),
              ),
            ),
          ),
          if (showPausedHero)
            Positioned(
              left: 0,
              top: topBarHeight,
              bottom: 110,
              child: AnimatedOpacity(
                opacity: showPausedHero ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PlayerPausedHero(
                    movie: widget.movie!,
                    season:
                        widget.episodes != null ? null : widget.selectedSeason,
                    episode:
                        widget.episodes != null ? null : widget.selectedEpisode,
                    episodeOverview: widget.episodeOverview,
                  ),
                ),
              ),
            ),
          if (showCenter)
            Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerCenterActionButton(
                      icon: Icons.replay_10_rounded,
                      onPressed: () => unawaited(
                        _seek(_position - const Duration(seconds: 10)),
                      ),
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 80,
                      iconSize: 44,
                      onPressed: () => unawaited(_playPause()),
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: Icons.forward_10_rounded,
                      onPressed: () => unawaited(
                        _seek(_position + const Duration(seconds: 10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.hasNextEpisode || widget.onNextEpisode != null)
            Positioned(
              bottom: 100,
              right: 24,
              child: PlayerFloatingChip(
                label: 'Next Episode',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () async {
                  await _saveProgress();
                  await widget.onNextEpisode?.call();
                },
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SeekBarWithPreview(
                          duration: _duration,
                          position: _position,
                          bufferedPosition: _buffered,
                          zones: buildSeekBarZones(
                            duration: _duration,
                            hasNextEpisode: widget.hasNextEpisode,
                          ),
                          onSeek: (t) => unawaited(_seek(t)),
                          onDragStart: () => _hideControlsTimer?.cancel(),
                          onDragEnd: _scheduleHideControls,
                        ),
                      ),
                      const SizedBox(width: 12),
                      PlayerTimeRange(
                        position: _position,
                        duration: _duration,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      width: double.infinity,
                      child: MouseRegion(
                        onEnter: (_) => playerChromeCancelSeekScrubs(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                PlayerFlatIconButton(
                                  icon: _playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  tooltip: _playing ? 'Pause' : 'Play',
                                  onPressed: () => unawaited(_playPause()),
                                ),
                                const SizedBox(width: 2),
                                PlayerFlatIconButton(
                                  icon: Icons.replay_10_rounded,
                                  tooltip: '-10s',
                                  onPressed: () => unawaited(
                                    _seek(
                                      _position - const Duration(seconds: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                PlayerFlatIconButton(
                                  icon: Icons.forward_10_rounded,
                                  tooltip: '+10s',
                                  onPressed: () => unawaited(
                                    _seek(
                                      _position + const Duration(seconds: 10),
                                    ),
                                  ),
                                ),
                                if (widget.hasNextEpisode ||
                                    widget.onNextEpisode != null) ...[
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: Icons.skip_next_rounded,
                                    tooltip: 'Next episode',
                                    onPressed: () async {
                                      await _saveProgress();
                                      await widget.onNextEpisode?.call();
                                    },
                                  ),
                                ],
                                const SizedBox(width: 6),
                                PlayerVolumeControl(
                                  volume: _volume,
                                  maxVolume: 100,
                                  compact: compact,
                                  onVolumeChanged: (v) =>
                                      unawaited(_setVolume(v)),
                                  onInteraction: _bumpControls,
                                  onDragStart: () =>
                                      _hideControlsTimer?.cancel(),
                                  onDragEnd: _scheduleHideControls,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (widget.onSwitchPlayer != null)
                                  Builder(
                                    builder: (anchor) => PlayerFlatIconButton(
                                      icon: Icons.smart_display_outlined,
                                      tooltip: 'Player',
                                      onPressed: () =>
                                          unawaited(_showPlayerMenu(anchor)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
