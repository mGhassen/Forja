import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_touch_seekbar.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
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
  late final PlayerStatusController _statusController = PlayerStatusController();
  late final ValueNotifier<bool> _isBufferingNotifier =
      ValueNotifier<bool>(false);

  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;

  bool _disposed = false;
  bool _isTv = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _playbackStartedNotified = false;
  bool _opening = false;
  bool _startPositionApplied = false;
  bool _loadingNextEp = false;
  double _volume = 100;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;

  late List<_ExoSource> _sources;
  int _sourceIndex = 0;
  final FocusNode _tvKeyFocus = FocusNode(debugLabel: 'exo-player-tv');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _sources = [];
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

  Future<List<_ExoSource>> _buildRankedSources() async {
    List<StreamSource> raw;
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      raw = await PlaybackSelection.rankAndDedupe(
        sources: widget.sources!,
        providerId: widget.activeProvider ?? '',
      );
    } else {
      raw = [
        StreamSource(
          url: widget.mediaPath,
          title: widget.title,
          type: 'video',
          headers: widget.headers,
        ),
      ];
    }
    return raw
        .map(
          (s) => _ExoSource(
            url: s.url,
            title: s.title,
            headers: s.headers ?? widget.headers,
          ),
        )
        .toList();
  }

  Future<void> _boot() async {
    final wasTv = _isTv;
    _isTv = await ExoPlayerBridge.isTelevision();
    if (mounted && _isTv != wasTv) setState(() {});
    _sources = await _buildRankedSources();
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
    _statusController.upsert(
      'source-$_sourceIndex',
      source.title,
      kind: StatusRouletteKind.loading,
    );
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
      final start = !_startPositionApplied
          ? (widget.startPosition ?? Duration.zero)
          : Duration.zero;
      _startPositionApplied = true;
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: source.url,
        headers: source.headers,
        startPosition: start,
        subtitles: subs,
      );
      await ExoPlayerBridge.setVolume(_viewId, _volume / 150.0);
    } catch (e) {
      debugPrint('[ExoPlayer] open failed: $e');
      await _failCurrentSource('Failed to open stream');
    } finally {
      _opening = false;
    }
  }

  Future<void> _failCurrentSource(String message) async {
    if (_sourceIndex < _sources.length) {
      PlaybackSelection.recordFailedUrl(_sources[_sourceIndex].url);
      _statusController.upsert(
        'source-$_sourceIndex',
        _sources[_sourceIndex].title,
        kind: StatusRouletteKind.failed,
      );
    }
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
        _isBufferingNotifier.value = false;
        _statusController.complete();
        if (!_playbackStartedNotified) {
          _playbackStartedNotified = true;
          widget.onPlaybackStarted?.call();
          _scrobbleStart();
        }
        break;
      case 'playing':
        setState(() {
          _isPlaying = event['value'] == true;
        });
        if (_isPlaying) _isBufferingNotifier.value = false;
        break;
      case 'buffering':
        _isBufferingNotifier.value = event['value'] == true;
        break;
      case 'progress':
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        final durMs = (event['duration'] as num?)?.toInt() ?? 0;
        final bufMs = (event['buffered'] as num?)?.toInt() ?? 0;
        setState(() {
          _position = Duration(milliseconds: posMs);
          if (durMs > 0) _duration = Duration(milliseconds: durMs);
          _buffered = Duration(milliseconds: bufMs);
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
        if (isVideoDecoderError(msg)) {
          debugPrint('[ExoPlayer] decoder error: $msg');
        }
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

  Future<void> _seekRelative(Duration delta) async {
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration.inMilliseconds > 0 && target > _duration)
            ? _duration
            : target;
    await ExoPlayerBridge.seekTo(_viewId, clamped);
    _startHideTimer();
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

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
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

  Future<void> _setVolume(double volume) async {
    final v = volume.clamp(0.0, 150.0);
    setState(() => _volume = v);
    await ExoPlayerBridge.setVolume(_viewId, v / 150.0);
    _startHideTimer();
  }

  void _mediaKitHint(String feature) {
    ForjaToast.info('$feature is not available in ExoPlayer — switch to MediaKit in Settings.');
    _startHideTimer();
  }

  Future<void> _exit() async {
    await _saveProgress();
    if (!mounted) return;
    if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
      ShellTvFocusCoordinator.handleShellBackKey();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _saveProgress();
    if (!mounted || !anchorContext.mounted) return;
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

  Future<void> _nextEpisode() async {
    final handler = widget.onNextEpisode;
    if (handler == null || _loadingNextEp) return;
    setState(() => _loadingNextEp = true);
    try {
      await handler();
    } finally {
      if (mounted) setState(() => _loadingNextEp = false);
    }
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

  String _currentStreamUrl() =>
      _sources.isNotEmpty ? _sources[_sourceIndex].url : widget.mediaPath;

  String _streamPickerLabel() {
    if (_sources.isEmpty) return 'Source';
    final title = _sources[_sourceIndex].title.trim();
    return title.isEmpty ? 'Source' : title;
  }

  bool get _hasStreamPicker => _sources.length > 1;

  bool get _hasEpisodePicker {
    final isTv = widget.movie?.mediaType == 'tv';
    return (isTv && widget.movie != null) ||
        (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);
  }

  @override
  void dispose() {
    _disposed = true;
    _tvKeyFocus.dispose();
    _statusController.dispose();
    _isBufferingNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _eventSub?.cancel();
    unawaited(ExoPlayerBridge.dispose(_viewId));
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildControlsOverlay() {
    const btnSize = 38.0;
    const iconSz = 20.0;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final tvFocus = _isTv;
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
      hasStatusMessage: _hasError,
      hasStatusActions: _hasError,
    );
    final showCenterActions = !playerStatusOverlayVisible(
      _statusController,
      _isBufferingNotifier.value,
    );

    final overlay = Stack(
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
            season: widget.hubEpisodes != null ? null : widget.selectedSeason,
            episode: widget.hubEpisodes != null ? null : widget.selectedEpisode,
            episodeLine: _episodeLine,
            statusMessage: _hasError ? _errorMessage : null,
            statusActions: _hasError
                ? PlayerTopStatusActions(
                    onRetry: () {
                      _sourceIndex = 0;
                      unawaited(_openCurrentSource());
                    },
                    onStream: _hasStreamPicker
                        ? () => _mediaKitHint('Source picker')
                        : null,
                  )
                : null,
            onBack: () => unawaited(_exit()),
            tvFocusable: tvFocus,
            trailing: PlayerTopBarActions(
              showPlayer: widget.onSwitchPlayer != null,
              onPlayer: widget.onSwitchPlayer != null
                  ? (anchorContext) => unawaited(_showPlayerMenu(anchorContext))
                  : null,
              showCast:
                  CastingService.instance.isAirPlayAvailable ||
                  CastingService.instance.isChromecastAvailable,
              onCast: () {
                showPlayerCastPicker(
                  context,
                  streamUrl: _currentStreamUrl(),
                  title: widget.title,
                  headers: widget.headers,
                  statusController: _statusController,
                );
                _startHideTimer();
              },
              showPip: PipService.instance.isSupported,
              onPip: () {
                _mediaKitHint('Picture-in-picture');
              },
            ),
          ),
        ),
        if (widget.movie != null)
          Positioned(
            left: 0,
            top: topBarHeight,
            bottom: 110,
            child: AnimatedOpacity(
              opacity: _isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _isPlaying,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PlayerPausedHero(
                    movie: widget.movie!,
                    season: widget.hubEpisodes != null
                        ? null
                        : widget.selectedSeason,
                    episode: widget.hubEpisodes != null
                        ? null
                        : widget.selectedEpisode,
                    episodeLine: _episodeLine,
                    episodeOverview: widget.episodeOverview,
                  ),
                ),
              ),
            ),
          ),
        if (showCenterActions)
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerCenterActionButton(
                    tvFocusable: tvFocus,
                    icon: Icons.replay_10_rounded,
                    onPressed: () =>
                        unawaited(_seekRelative(const Duration(seconds: -10))),
                  ),
                  const SizedBox(width: 24),
                  PlayerCenterActionButton(
                    tvFocusable: tvFocus,
                    icon: _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 80,
                    iconSize: 44,
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(width: 24),
                  PlayerCenterActionButton(
                    tvFocusable: tvFocus,
                    icon: Icons.forward_10_rounded,
                    onPressed: () =>
                        unawaited(_seekRelative(const Duration(seconds: 10))),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerTouchSeekBar(
                    duration: _duration,
                    position: _position,
                    bufferedPosition: _buffered,
                    onSeek: (t) {
                      unawaited(ExoPlayerBridge.seekTo(_viewId, t));
                      _startHideTimer();
                    },
                    onDragStart: () => _hideTimer?.cancel(),
                    onDragEnd: _startHideTimer,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: btnSize,
                            iconSize: iconSz,
                            onPressed: _togglePlayPause,
                          ),
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: Icons.replay_10_rounded,
                            size: btnSize,
                            iconSize: iconSz,
                            onPressed: () => unawaited(
                              _seekRelative(const Duration(seconds: -10)),
                            ),
                          ),
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: Icons.forward_10_rounded,
                            size: btnSize,
                            iconSize: iconSz,
                            onPressed: () => unawaited(
                              _seekRelative(const Duration(seconds: 10)),
                            ),
                          ),
                          PlayerVolumeControl(
                            volume: _volume,
                            maxVolume: 150,
                            size: btnSize,
                            iconSize: iconSz,
                            tvFocusable: tvFocus,
                            compact: compact,
                            onVolumeChanged: (v) => unawaited(_setVolume(v)),
                            onInteraction: _startHideTimer,
                            onDragStart: () => _hideTimer?.cancel(),
                            onDragEnd: _startHideTimer,
                          ),
                          const SizedBox(width: 6),
                          PlayerTimeRange(
                            position: _position,
                            duration: _duration,
                            fontSize: 11,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_hasStreamPicker)
                            PlayerStreamPickerButton(
                              tvFocusable: tvFocus,
                              size: btnSize,
                              iconSize: iconSz - 2,
                              label: _streamPickerLabel(),
                              onPressedWithContext: (_) =>
                                  _mediaKitHint('Source picker'),
                            ),
                          if (_hasEpisodePicker)
                            PlayerFlatIconButton(
                              tvFocusable: tvFocus,
                              icon: Icons.video_library_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressedWithContext: (_) =>
                                  _mediaKitHint('Episodes'),
                            ),
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: Icons.audiotrack_rounded,
                            size: btnSize,
                            iconSize: iconSz,
                            tooltip: 'Audio',
                            onPressedWithContext: (_) => _mediaKitHint('Audio'),
                          ),
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: Icons.subtitles_outlined,
                            size: btnSize,
                            iconSize: iconSz,
                            onPressedWithContext: (_) =>
                                _mediaKitHint('Subtitles'),
                          ),
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: Icons.hd_outlined,
                            size: btnSize,
                            iconSize: iconSz,
                            tooltip: 'Quality',
                            onPressedWithContext: (_) =>
                                _mediaKitHint('Quality'),
                          ),
                          PlayerFlatIconButton(
                            tvFocusable: tvFocus,
                            icon: Icons.settings_outlined,
                            size: btnSize,
                            iconSize: iconSz,
                            onPressedWithContext: (_) =>
                                _mediaKitHint('Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!tvFocus) return overlay;
    return FocusScope(
      debugLabel: 'player-chrome',
      child: FocusTraversalGroup(child: overlay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = PopScope(
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
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                ),
              ),
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ExcludeFocus(
                  excluding: _isTv && !_showControls,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildControlsOverlay(),
                  ),
                ),
              ),
              if (widget.hasNextEpisode && widget.onNextEpisode != null)
                Positioned(
                  bottom: 120,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingNextEp ? null : () => unawaited(_nextEpisode()),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_loadingNextEp)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Text(
                                  'Next Episode',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              PlayerStatusOverlay(
                controller: _statusController,
                bufferingListenable: _isBufferingNotifier,
                header: 'CHECKING SOURCES',
              ),
            ],
          ),
        ),
      ),
    );

    if (!_isTv) return body;
    return PlayerTvKeyScope(
      enabled: true,
      focusNode: _tvKeyFocus,
      showControls: _showControls,
      onBack: () => unawaited(_exit()),
      onPlayPause: _togglePlayPause,
      onShowControls: () {
        setState(() => _showControls = true);
        _startHideTimer();
      },
      onSeekBack: () =>
          unawaited(_seekRelative(const Duration(seconds: -10))),
      onSeekForward: () =>
          unawaited(_seekRelative(const Duration(seconds: 10))),
      onVolumeUp: () => unawaited(_setVolume(_volume + 5)),
      onVolumeDown: () => unawaited(_setVolume(_volume - 5)),
      onToggleControls: _toggleControls,
      child: body,
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
