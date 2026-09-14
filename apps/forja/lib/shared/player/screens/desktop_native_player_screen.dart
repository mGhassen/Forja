import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/store/list_follow_from_watched.dart';
import 'package:forja/shared/player/avplayer/av_player_bridge.dart';
import 'package:forja/shared/player/avplayer/av_player_view.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/controls/menus/player_app_menu.dart';
import 'package:forja/shared/player/controls/seek/seek_bar_with_preview.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/player/vlc/vlc_player_bridge.dart';
import 'package:forja/shared/player/vlc/vlc_player_view.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/playback/loading_overlay.dart';
import 'package:forja/shell/desktop/desktop_window_geometry.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_theme.dart';
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
  final Future<void> Function(Duration position, Duration duration)?
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
      if (mounted) {
        ForjaToast.error('Could not open stream');
      }
    }
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
        if (mounted) ForjaToast.error(msg);
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
    if (widget.onSaveProgress != null) {
      await widget.onSaveProgress!(_position, _duration);
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
      streamUrl: _url,
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _bumpControls(),
        child: GestureDetector(
          onTap: () {
            setState(() => _controlsVisible = !_controlsVisible);
            if (_controlsVisible) _scheduleHideControls();
          },
          onDoubleTap: () => unawaited(_playPause()),
          child: Scaffold(
            backgroundColor: DesignTokens.bgDark,
            body: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: !_ready
                      ? const SizedBox.shrink()
                      : _av
                          ? AvPlayerView(viewId: _viewId)
                          : VlcPlayerView(
                              viewId: _viewId,
                              textureId: _vlcTextureId,
                            ),
                ),
                if (_buffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: ForjaShellColors.brandGreen,
                    ),
                  ),
                if (_controlsVisible) _buildChrome(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChrome() {
    final totalMs = _duration.inMilliseconds;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.75),
            ],
            stops: const [0, 0.2, 0.65, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    PlayerFlatIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onPressed: () => unawaited(_exit()),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (anchorCtx) => PlayerFlatIconButton(
                        icon: Icons.smart_display_outlined,
                        tooltip: 'Player',
                        onPressed: () => unawaited(_showPlayerMenu(anchorCtx)),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    if (totalMs > 0)
                      SeekBarWithPreview(
                        position: _position,
                        duration: _duration,
                        bufferedPosition: _buffered,
                        onSeek: (d) => unawaited(_seek(d)),
                      )
                    else
                      LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        color: ForjaShellColors.brandGreen.withValues(alpha: 0.5),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PlayerFlatIconButton(
                          icon: _playing ? Icons.pause : Icons.play_arrow,
                          tooltip: _playing ? 'Pause' : 'Play',
                          onPressed: () => unawaited(_playPause()),
                        ),
                        PlayerFlatIconButton(
                          icon: Icons.replay_10,
                          tooltip: '-10s',
                          onPressed: () => unawaited(
                            _seek(_position - const Duration(seconds: 10)),
                          ),
                        ),
                        PlayerFlatIconButton(
                          icon: Icons.forward_10,
                          tooltip: '+10s',
                          onPressed: () => unawaited(
                            _seek(_position + const Duration(seconds: 10)),
                          ),
                        ),
                        if (widget.hasNextEpisode ||
                            widget.onNextEpisode != null)
                          PlayerFlatIconButton(
                            icon: Icons.skip_next,
                            tooltip: 'Next episode',
                            onPressed: () async {
                              await _saveProgress();
                              await widget.onNextEpisode?.call();
                            },
                          ),
                        const Spacer(),
                        Text(
                          '${formatDuration(_position)} / '
                          '${totalMs > 0 ? formatDuration(_duration) : '--:--'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
