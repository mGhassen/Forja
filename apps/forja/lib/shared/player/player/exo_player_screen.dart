import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:rust/rust.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Android built-in player using native Media3 ExoPlayer.
class ExoPlayerScreen extends StatefulWidget {
  const ExoPlayerScreen({
    super.key,
    required this.mediaPath,
    required this.title,
    this.audioUrl,
    this.headers,
    this.movie,
    this.selectedSeason,
    this.selectedEpisode,
    this.magnetLink,
    this.activeProvider,
    this.startPosition,
    this.sources,
    this.fileIndex,
    this.externalSubtitles,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.hubEpisodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.onSaveProgress,
    this.onPlaybackStarted,
    this.onAllSourcesExhausted,
    this.builtInEngine = BuiltInPlayerEngine.exoPlayer,
    this.onSwitchPlayer,
  });

  final String mediaPath;
  final String title;
  final String? audioUrl;
  final Map<String, String>? headers;
  final Movie? movie;
  final int? selectedSeason;
  final int? selectedEpisode;
  final String? magnetLink;
  final String? activeProvider;
  final Duration? startPosition;
  final List<StreamSource>? sources;
  final int? fileIndex;
  final List<Map<String, dynamic>>? externalSubtitles;
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;
  final List<PlayerHubEpisode>? hubEpisodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerHubEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;
  final Future<void> Function(Duration position, Duration duration)? onSaveProgress;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerSwitchHandler? onSwitchPlayer;

  @override
  State<ExoPlayerScreen> createState() => _ExoPlayerScreenState();
}

class _ExoPlayerScreenState extends State<ExoPlayerScreen>
    with WidgetsBindingObserver {
  static int _nextViewId = 1;

  late final int _viewId = _nextViewId++;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;

  bool _disposed = false;
  bool _isTv = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _playbackStartedNotified = false;
  bool _opening = false;
  bool _startPositionApplied = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late List<_ExoSource> _sources;
  int _sourceIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _sources = _buildSources();
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ForjaToast.info(
          'Separate audio track not supported in ExoPlayer — use MediaKit in Settings.',
        );
      });
    }
    unawaited(_boot());
  }

  List<_ExoSource> _buildSources() {
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      return dedupeStreamSources(widget.sources!)
          .map(
            (s) => _ExoSource(
              url: s.url,
              title: s.title,
              headers: s.headers ?? widget.headers,
            ),
          )
          .toList();
    }
    return [
      _ExoSource(
        url: widget.mediaPath,
        title: widget.title,
        headers: widget.headers,
      ),
    ];
  }

  Future<void> _boot() async {
    _isTv = await ExoPlayerBridge.isTelevision();
    if (_isTv) {
      HardwareKeyboard.instance.addHandler(_handleTvKey);
    }
    _eventSub = ExoPlayerBridge.eventsFor(_viewId).listen(_onNativeEvent);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _disposed) return;
    await _openCurrentSource();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_saveProgress());
    });
  }

  Future<void> _openCurrentSource() async {
    if (_opening || _disposed) return;
    _opening = true;
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    final source = _sources[_sourceIndex];
    debugPrint(
      '[ExoPlayer] Trying source ${_sourceIndex + 1}/${_sources.length}: ${source.title}',
    );
    final subs = (widget.externalSubtitles ?? [])
        .where((s) => (s['url'] ?? '').toString().isNotEmpty)
        .map(
          (s) => {
            'url': s['url'].toString(),
            'lang': (s['lang'] ?? 'Unknown').toString(),
          },
        )
        .toList();
    try {
      final start = !_startPositionApplied ? (widget.startPosition ?? Duration.zero) : Duration.zero;
      _startPositionApplied = true;
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: source.url,
        headers: source.headers,
        startPosition: start,
        subtitles: subs,
      );
    } catch (e) {
      debugPrint('[ExoPlayer] open failed: $e');
      await _failCurrentSource('Failed to open stream');
    } finally {
      _opening = false;
    }
  }

  Future<void> _failCurrentSource(String message) async {
    if (_sourceIndex + 1 < _sources.length) {
      _sourceIndex++;
      await ExoPlayerBridge.stop(_viewId);
      await _openCurrentSource();
      return;
    }
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _showControls = true;
    });
    widget.onAllSourcesExhausted?.call();
  }

  void _onNativeEvent(Map<dynamic, dynamic> event) {
    if (_disposed) return;
    final type = event['type']?.toString() ?? '';
    switch (type) {
      case 'ready':
        if (!_playbackStartedNotified) {
          _playbackStartedNotified = true;
          widget.onPlaybackStarted?.call();
          _scrobbleStart();
        }
        break;
      case 'playing':
        setState(() => _isPlaying = event['value'] == true);
        break;
      case 'buffering':
        setState(() => _isBuffering = event['value'] == true);
        break;
      case 'progress':
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        final durMs = (event['duration'] as num?)?.toInt() ?? 0;
        setState(() {
          _position = Duration(milliseconds: posMs);
          if (durMs > 0) _duration = Duration(milliseconds: durMs);
        });
        break;
      case 'ended':
        setState(() {
          _isPlaying = false;
          _showControls = true;
        });
        break;
      case 'error':
        final msg = event['message']?.toString() ?? 'Playback error';
        unawaited(_failCurrentSource(msg));
        break;
    }
  }

  void _scrobbleStart() {
    final movie = widget.movie;
    if (movie == null) return;
    TraktService().scrobbleStart(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      progressPercent: 0,
    );
    SimklService().scrobbleStart(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
  }

  Future<void> _saveProgress() async {
    if (widget.onSaveProgress == null || _duration.inMilliseconds <= 0) return;
    await widget.onSaveProgress!(_position, _duration);
  }

  bool _handleTvKey(KeyEvent event) {
    if (_disposed || _hasError) return false;
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _togglePlayPause();
        return true;
      case LogicalKeyboardKey.arrowLeft:
        unawaited(_seekRelative(const Duration(seconds: -10)));
        return true;
      case LogicalKeyboardKey.arrowRight:
        unawaited(_seekRelative(const Duration(seconds: 10)));
        return true;
      case LogicalKeyboardKey.mediaPlayPause:
        _togglePlayPause();
        return true;
      case LogicalKeyboardKey.mediaFastForward:
        unawaited(_seekRelative(const Duration(seconds: 10)));
        return true;
      case LogicalKeyboardKey.mediaRewind:
        unawaited(_seekRelative(const Duration(seconds: -10)));
        return true;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        unawaited(_exit());
        return true;
      default:
        return false;
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration.inMilliseconds > 0 && target > _duration)
            ? _duration
            : target;
    await ExoPlayerBridge.seekTo(_viewId, clamped);
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      unawaited(ExoPlayerBridge.pause(_viewId));
    } else {
      unawaited(ExoPlayerBridge.play(_viewId));
    }
    setState(() => _showControls = true);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_disposed && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _exit() async {
    await _saveProgress();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _saveProgress();
    if (!mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) async {
        await handler(
          _position,
          builtInEngine: builtInEngine,
          externalPlayer: externalPlayer,
        );
      },
    );
    _startHideTimer();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_isTv) {
      HardwareKeyboard.instance.removeHandler(_handleTvKey);
    }
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _eventSub?.cancel();
    unawaited(ExoPlayerBridge.dispose(_viewId));
    WakelockPlus.disable();
    super.dispose();
  }

  String? get _episodeLine {
    if (widget.hubEpisodeNumber != null) {
      return 'Episode ${widget.hubEpisodeNumber}';
    }
    if (widget.selectedEpisode != null && widget.selectedSeason != null) {
      return 'S${widget.selectedSeason} E${widget.selectedEpisode}';
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exit();
      },
      child: Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              ExoPlayerView(viewId: _viewId),
              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try MediaKit in Settings → Built-in engine',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isBuffering && !_hasError)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                ),
              IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls || _hasError ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xCC000000),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                        stops: [0, 0.25, 0.7, 1],
                      ),
                    ),
                  ),
                ),
              ),
              if (_showControls || _hasError)
                Column(
                  children: [
                    PlayerTopBar(
                      title: widget.title,
                      season: widget.selectedSeason,
                      episode: widget.selectedEpisode,
                      episodeLine: _episodeLine,
                      onBack: () => unawaited(_exit()),
                      trailing: widget.onSwitchPlayer != null
                          ? PlayerTopBarActions(
                              showPlayer: true,
                              onPlayer: () => unawaited(
                                _showPlayerMenu(context),
                              ),
                            )
                          : null,
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? (_position.inMilliseconds /
                                          _duration.inMilliseconds)
                                      .clamp(0.0, 1.0)
                                  : 0,
                              onChanged: _duration.inMilliseconds > 0
                                  ? (v) {
                                      final ms =
                                          (v * _duration.inMilliseconds).round();
                                      unawaited(
                                        ExoPlayerBridge.seekTo(
                                          _viewId,
                                          Duration(milliseconds: ms),
                                        ),
                                      );
                                    }
                                  : null,
                              activeColor: const Color(0xFF7C3AED),
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PlayerFlatIconButton(
                            icon: Icons.replay_10_rounded,
                            onPressed: () =>
                                unawaited(_seekRelative(const Duration(seconds: -10))),
                          ),
                          const SizedBox(width: 16),
                          PlayerFlatIconButton(
                            icon: _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 56,
                            iconSize: 32,
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 16),
                          PlayerFlatIconButton(
                            icon: Icons.forward_10_rounded,
                            onPressed: () =>
                                unawaited(_seekRelative(const Duration(seconds: 10))),
                          ),
                          if (widget.onSwitchPlayer != null) ...[
                            const SizedBox(width: 16),
                            PlayerFlatIconButton(
                              icon: Icons.smart_display_outlined,
                              tooltip: 'Player',
                              onPressedWithContext: (ctx) =>
                                  unawaited(_showPlayerMenu(ctx)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() => _showControls = !_showControls);
                    if (_showControls) _startHideTimer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExoSource {
  const _ExoSource({
    required this.url,
    required this.title,
    this.headers,
  });

  final String url;
  final String title;
  final Map<String, String>? headers;
}
