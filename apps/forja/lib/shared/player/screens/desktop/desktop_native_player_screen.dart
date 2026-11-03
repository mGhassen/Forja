import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/downloads/download_enqueue.dart';
import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/store/list_follow_from_watched.dart';
import 'package:forja/shared/playback/loading_overlay.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/playback/open/player_source_resolve.dart';
import 'package:forja/shared/playback/probe/playback_stream_guards.dart';
import 'package:forja/shared/playback/probe/stream_drm_platform.dart';
import 'package:forja/shared/playback/sources/stremio_external_link.dart';
import 'package:forja/shared/playback/stream_provider_probe.dart';
import 'package:forja/shared/player/avplayer/av_player_bridge.dart';
import 'package:forja/shared/player/avplayer/av_player_view.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/chrome/player_next_episode_chip.dart';
import 'package:forja/shared/player/controls/chrome/player_status_roulette.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/controls/episodes/player_episode_menu.dart';
import 'package:forja/shared/player/controls/episodes/player_episode_panel.dart';
import 'package:forja/shared/player/controls/menus/player_app_menu.dart';
import 'package:forja/shared/player/controls/menus/player_menus.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/controls/menus/player_provider_menu.dart';
import 'package:forja/shared/player/controls/seek/seek_bar_with_preview.dart';
import 'package:forja/shared/player/controls/seek/seek_bar_zones.dart';
import 'package:forja/shared/player/controls/sources/panel/player_sources_panel.dart';
import 'package:forja/shared/player/controls/sources/stream/player_stream_menu.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_chrome.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/player/platform/pip_service.dart';
import 'package:forja/shared/player/resolvers/episode_switch_resolver.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/player/vlc/vlc_player_bridge.dart';
import 'package:forja/shared/player/vlc/vlc_player_view.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shell/desktop/desktop_window_geometry.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:rust/rust.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'desktop_native_player_chrome.dart';
part 'desktop_native_player_menus.dart';

/// Catalog VOD on desktop via AVPlayer (macOS) or libVLC (macOS / Windows).
///
/// Thin sibling of [ExoPlayerScreen] — MediaKit-parity chrome, not the
/// DesktopPlayerScreen mixin god. Track APIs (audio/subs/quality) and desktop
/// OS PiP stay toast stubs until native bridges grow those surfaces.
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
    this.magnetLink,
    this.activeProvider,
    this.startPosition,
    this.sources,
    this.fileIndex,
    this.externalSubtitles,
    this.stremioId,
    this.stremioAddonBaseUrl,
    this.providers,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.episodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.enginePlaySession,
    this.onSaveProgress,
    this.onSourcePinned,
    this.pinSource = false,
    this.streamsPrevalidated = false,
    this.onPlaybackStarted,
    this.onAllSourcesExhausted,
    this.onReloadStreams,
    this.sourcesListNotifier,
    this.providerSourcesCache,
    this.providerProbesNotifier,
    this.onSwitchPlayer,
  });

  final String mediaPath;
  final String title;
  final BuiltInPlayerEngine builtInEngine;
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
  final String? stremioId;
  final String? stremioAddonBaseUrl;
  final Map<String, dynamic>? providers;
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;
  final List<PlayerKitEpisode>? episodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerKitEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;
  final EnginePlaySession? enginePlaySession;
  final Future<void> Function(
    Duration position,
    Duration duration, {
    String? sourceId,
    String? streamUrl,
  })?
  onSaveProgress;
  final Future<void> Function(String sourceUrl, String sourceTitle)?
  onSourcePinned;
  final bool pinSource;
  final bool streamsPrevalidated;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final Future<List<StreamSource>?> Function()? onReloadStreams;
  final ValueNotifier<List<StreamSource>>? sourcesListNotifier;
  final ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final PlayerSwitchHandler? onSwitchPlayer;

  @override
  State<DesktopNativePlayerScreen> createState() =>
      _DesktopNativePlayerScreenState();
}

class _DesktopNativePlayerScreenState extends State<DesktopNativePlayerScreen>
    with _DesktopNativeChrome, _DesktopNativeMenus
    implements InAppMiniPlayerSession {
  static int _nextViewId = 1;

  late final int _viewId = _nextViewId++;
  int? _vlcTextureId;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;
  Timer? _progressSaveTimer;
  Timer? _hideControlsTimer;

  String _url = '';
  Map<String, String>? _headers;
  String? _currentProvider;
  String? _activeMagnet;
  String? _catalogAddonBaseUrl;
  String? _catalogAddonName;
  String? _catalogSourceKind;
  String? _currentPlayingCatalogUrl;
  String? _catalogStreamRowKey;
  List<StreamSource>? _currentSources;

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
  bool _isFullscreen = false;
  bool _loadingNextEp = false;
  bool _hasPrevEpisodeAdjacent = false;
  bool _hasNextEpisodeAdjacent = false;
  bool _nearEndOfEpisode = false;
  bool _autoNextCountdown = false;
  bool _autoNextDismissed = false;
  bool _skipDismissed = false;
  bool _providerPinned = false;
  bool _sourcePinned = false;
  bool _audioPinned = false;
  bool _subtitlePinned = false;
  double _volume = 100;
  BoxFit _videoFit = BoxFit.contain;

  IntroDbResponse? _introDbData;
  String? _activeSkipLabel;
  Duration? _activeSkipTarget;
  Duration? _autoSkipLatchedTarget;

  final PlayerStatusController _statusController = PlayerStatusController();
  final ValueNotifier<Set<String>> _providerLoadFailures =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<int> _streamMenuRefreshTick = ValueNotifier<int>(0);
  late final ValueNotifier<Map<String, List<StreamSource>>>
  _ownedProviderSourcesCache;
  final Map<String, int> _providerLoadGens = {};
  Completer<void>? _stopForNewPlayCompleter;

  late final FocusNode _miniRootFocus = FocusNode(
    debugLabel: 'native-in-app-mini-root',
  );
  late final FocusNode _miniPlayPauseFocus = FocusNode(
    debugLabel: 'native-in-app-mini-play',
  );
  late final FocusNode _miniExpandFocus = FocusNode(
    debugLabel: 'native-in-app-mini-expand',
  );
  late final FocusNode _miniCloseFocus = FocusNode(
    debugLabel: 'native-in-app-mini-close',
  );

  bool get _av => widget.builtInEngine == BuiltInPlayerEngine.avPlayer;
  bool get _vlc => widget.builtInEngine == BuiltInPlayerEngine.vlc;

  ValueNotifier<Map<String, List<StreamSource>>>
  get _liveProviderSourcesCache =>
      widget.providerSourcesCache ?? _ownedProviderSourcesCache;

  @override
  FocusNode get miniRootFocus => _miniRootFocus;

  @override
  bool get isPlaying => _playing;

  @override
  void initState() {
    super.initState();
    _url = widget.mediaPath;
    _headers = widget.headers;
    _currentProvider = widget.activeProvider;
    _activeMagnet = widget.magnetLink;
    _catalogAddonBaseUrl = widget.stremioAddonBaseUrl;
    _catalogSourceKind = _initialCatalogSourceKind();
    _catalogStreamRowKey = takePendingMetaStreamRowKey();
    if (widget.magnetLink == null || widget.magnetLink!.isEmpty) {
      _currentPlayingCatalogUrl = widget.mediaPath;
    }
    String? seedAddon;
    for (final s in widget.sources ?? const <StreamSource>[]) {
      final t = s.title.trim();
      if (t.isEmpty) continue;
      final lines = splitSourceButtonLines(t);
      if (lines.server != null) {
        seedAddon = '${lines.label} · ${lines.server}';
        break;
      }
    }
    _catalogAddonName = seedAddon;
    _position = widget.startPosition ?? Duration.zero;
    _ownedProviderSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {},
    );
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      _currentSources = dedupeStreamSources(widget.sources!);
      final pid = _currentProvider;
      if (pid != null && pid.isNotEmpty) {
        _ownedProviderSourcesCache.value = {pid: _currentSources!};
      }
    }
    _providerPinned = widget.pinSource;
    _sourcePinned = widget.pinSource;
    widget.sourcesListNotifier?.addListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_onLiveSourcesUpdated);
    InAppMiniPlayerController.instance.attach(this);
    unawaited(_boot());
    unawaited(_loadPlayerAutoPins());
    unawaited(_fetchIntroDbTimestamps());
    unawaited(_refreshAdjacentEpisodeFlags());
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_disposed && _playing) unawaited(_saveProgress());
    });
    _scheduleHideControls();
  }

  void _onLiveSourcesUpdated() {
    if (_disposed || !mounted) return;
    final live = widget.sourcesListNotifier?.value;
    if (live == null || live.isEmpty) {
      _streamMenuRefreshTick.value++;
      return;
    }
    final merged = dedupeStreamSources(live);
    if (_playbackStartedNotified &&
        _currentPlayingCatalogUrl != null &&
        !merged.any(
          (s) =>
              s.url == _url ||
              s.url == _currentPlayingCatalogUrl ||
              s.catalogUrl == _currentPlayingCatalogUrl,
        )) {
      _streamMenuRefreshTick.value++;
      return;
    }
    setState(() => _currentSources = merged);
    final pid = _currentProvider;
    if (pid != null && pid.isNotEmpty && merged.isNotEmpty) {
      _liveProviderSourcesCache.value = {
        ..._liveProviderSourcesCache.value,
        pid: merged,
      };
    }
    _streamMenuRefreshTick.value++;
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
      final prepared = await _prepareOpenTarget(
        mediaPath: widget.mediaPath,
        headers: widget.headers,
        providerId: widget.activeProvider,
      );
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

  Future<({String url, Map<String, String>? headers})> _prepareOpenTarget({
    required String mediaPath,
    Map<String, String>? headers,
    String? providerId,
  }) async {
    var openUrl = normalizePlaybackStreamUrl(mediaPath);
    final rawHeaders = headers ?? const <String, String>{};
    final proxiedExt = await proxyExtensionlessHlsIfNeeded(
      streamUrl: openUrl,
      headers: rawHeaders,
      providerId: providerId,
    );
    openUrl = proxiedExt.url;
    final catalogForHeaders = hlsProxyTargetUrl(openUrl) ?? openUrl;
    final hdrs =
        (isLocalLoopbackPlayUrl(openUrl) &&
            shouldProxyExtensionlessHls(catalogForHeaders))
        ? const <String, String>{}
        : resolvePlaybackHttpHeaders(
            headers,
            streamUrl: catalogForHeaders,
            providerId: providerId,
          );
    final isRemoteHttp =
        (openUrl.startsWith('http://') || openUrl.startsWith('https://')) &&
        !isLocalTorrentStreamUrl(openUrl) &&
        !isLocalLoopbackPlayUrl(openUrl);
    final attachHeaders = hdrs.isNotEmpty && isRemoteHttp;
    return (url: openUrl, headers: attachHeaders ? hdrs : null);
  }

  String _shortUrl(String url) {
    if (url.length <= 96) return url;
    return '${url.substring(0, 96)}…';
  }

  Future<void> _failoverToMediaKit(String reason) async {
    if (_failoverToMediaKitUsed || _disposed) return;
    final handler = widget.onSwitchPlayer;
    if (handler == null) {
      if (mounted)
        ForjaToast.error(context.l10n.playerScreenCouldNotOpenStream);
      if (!_playbackStartedNotified) {
        widget.onAllSourcesExhausted?.call();
      }
      return;
    }
    _failoverToMediaKitUsed = true;
    debugPrint('[DesktopNative] failover → MediaKit ($reason)');
    if (mounted) ForjaToast.info(context.l10n.playerScreenSwitchingToMediaKit);
    await handler(
      _position,
      builtInEngine: BuiltInPlayerEngine.mediaKit,
      streamUrl: _url.isNotEmpty ? _url : widget.mediaPath,
      headers: _headers ?? widget.headers,
      activeProvider: _currentProvider ?? widget.activeProvider,
      sources: _currentSources ?? widget.sources,
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
        _applyPlayheadChrome(pos);
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
        sourceId: _currentProvider ?? widget.activeProvider,
        streamUrl: durableUrl ?? playUrl,
      );
      return;
    }
    final movie = widget.movie;
    if (movie == null) return;
    final provider = _currentProvider ?? widget.activeProvider;
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
      if (!_disposed &&
          mounted &&
          _playing &&
          !InAppMiniPlayerController.instance.isActive) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _exit() async {
    if (dismissAnyPlayerChromeOverlay()) return;
    await _saveProgress();
    if (!mounted) return;
    await DesktopWindowGeometry.leavePlayerChrome();
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
          activeProvider: _currentProvider ?? widget.activeProvider,
          sources: _currentSources ?? widget.sources,
        );
      },
    );
    _bumpControls();
  }

  Future<void> _toggleFullscreen() async {
    final next = await DesktopWindowGeometry.toggleFullscreen();
    if (mounted) setState(() => _isFullscreen = next);
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (InAppMiniPlayerController.instance.isActive) {
      return KeyEventResult.ignored;
    }
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
      if (dismissAnyPlayerChromeOverlay()) return KeyEventResult.handled;
      if (_isFullscreen) {
        unawaited(_toggleFullscreen());
        return KeyEventResult.handled;
      }
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
        _escapeArmed = false;
        return KeyEventResult.handled;
      }
      if (!_escapeArmed) {
        _escapeArmed = true;
        ForjaToast.info(context.l10n.playerScreenPressEscAgain);
        return KeyEventResult.handled;
      }
      unawaited(_exit());
      return KeyEventResult.handled;
    }
    _bumpControls();
    return KeyEventResult.ignored;
  }

  @override
  Future<void> pauseForMini() async {
    if (_disposed) return;
    try {
      if (_av) {
        await AvPlayerBridge.pause(_viewId);
      } else {
        await VlcPlayerBridge.pause(_viewId);
      }
    } catch (e) {
      debugPrint('[DesktopNative] pauseForMini: $e');
    }
  }

  @override
  Future<void> playFromMini() async {
    if (_disposed) return;
    try {
      if (_av) {
        await AvPlayerBridge.play(_viewId);
      } else {
        await VlcPlayerBridge.play(_viewId);
      }
    } catch (e) {
      debugPrint('[DesktopNative] playFromMini: $e');
    }
  }

  @override
  void onEnteredMini() {
    if (!mounted || _disposed) return;
    setState(() {
      _controlsVisible = false;
      _escapeArmed = false;
    });
  }

  @override
  void onExpandedFromMini() {
    if (!mounted || _disposed) return;
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  @override
  Future<void> closeFromMini() async {
    await _exit();
  }

  @override
  Future<void> stopForNewPlay() async {
    final existing = _stopForNewPlayCompleter;
    if (existing != null) return existing.future;
    final c = Completer<void>();
    _stopForNewPlayCompleter = c;
    try {
      await _saveProgress();
      if (_av) {
        try {
          await AvPlayerBridge.pause(_viewId);
        } catch (_) {}
      } else {
        try {
          await VlcPlayerBridge.pause(_viewId);
        } catch (_) {}
      }
    } finally {
      if (!c.isCompleted) c.complete();
      _stopForNewPlayCompleter = null;
    }
  }

  Widget _buildNativeVideo() {
    final child = _av
        ? AvPlayerView(viewId: _viewId)
        : VlcPlayerView(viewId: _viewId, textureId: _vlcTextureId);
    return FittedBox(
      fit: _videoFit,
      clipBehavior: Clip.hardEdge,
      child: AspectRatio(aspectRatio: 16 / 9, child: child),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    widget.sourcesListNotifier?.removeListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.removeListener(_onLiveSourcesUpdated);
    InAppMiniPlayerController.instance.detach(this);
    PlayerSourcesPanel.dismiss(cancelEngine: false);
    PlayerStreamMenu.dismiss();
    PlayerPopupPanel.dismiss();
    PlayerKitEpisodePanel.dismiss();
    _progressSaveTimer?.cancel();
    _hideControlsTimer?.cancel();
    unawaited(_eventSub?.cancel());
    unawaited(WakelockPlus.disable());
    _statusController.dispose();
    _providerLoadFailures.dispose();
    _streamMenuRefreshTick.dispose();
    _ownedProviderSourcesCache.dispose();
    _miniRootFocus.dispose();
    _miniPlayPauseFocus.dispose();
    _miniExpandFocus.dispose();
    _miniCloseFocus.dispose();
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
      child: ListenableBuilder(
        listenable: InAppMiniPlayerController.instance.active,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final mini = InAppMiniPlayerController.instance.isActive;
    final compact = MediaQuery.sizeOf(context).width < 900;
    return MouseRegion(
      onHover: (_) {
        if (!mini) _bumpControls();
      },
      cursor: (!mini && !_controlsVisible)
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      child: Scaffold(
        backgroundColor: mini ? Colors.transparent : Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!mini) const ColoredBox(color: Colors.black),
            if (_ready)
              ValueListenableBuilder<Size>(
                valueListenable: InAppMiniPlayerController.instance.size,
                builder: (context, miniSize, _) {
                  return Positioned(
                    left: mini ? null : 0,
                    top: mini ? null : 0,
                    right: mini ? 16 : 0,
                    bottom: mini ? 16 : 0,
                    width: mini ? miniSize.width : null,
                    height: mini ? miniSize.height : null,
                    child: Material(
                      elevation: mini ? 12 : 0,
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(mini ? 10 : 0),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(child: _buildNativeVideo()),
                          if (mini)
                            InAppMiniPlayerChrome(
                              playing: _playing,
                              rootFocus: _miniRootFocus,
                              playPauseFocus: _miniPlayPauseFocus,
                              expandFocus: _miniExpandFocus,
                              closeFocus: _miniCloseFocus,
                              onPlayPause: () {
                                unawaited(
                                  InAppMiniPlayerController.instance
                                      .togglePlayPause(),
                                );
                              },
                              onExpand: () {
                                unawaited(
                                  InAppMiniPlayerController.instance.expand(),
                                );
                              },
                              onClose: () {
                                unawaited(
                                  InAppMiniPlayerController.instance.close(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (!mini && (!_ready || _buffering))
              const Center(
                child: CircularProgressIndicator(
                  color: ForjaShellColors.brandGreen,
                ),
              ),
            // Always mounted (MediaKit parity) so click still pauses when chrome
            // is hidden; hover alone must not be required to arm taps.
            if (!mini)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    unawaited(_playPause());
                    _bumpControls();
                  },
                  onDoubleTap: () => unawaited(_toggleFullscreen()),
                  child: const SizedBox.expand(),
                ),
              ),
            if (!mini && _controlsVisible) _buildChrome(compact: compact),
            if (!mini && (_showSkipChip || _showNextEpChip))
              Positioned(
                bottom: 100,
                right: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_showSkipChip)
                      PlayerFloatingChip(
                        label: _activeSkipLabel!,
                        onPressed: _performSkip,
                      ),
                    if (_showSkipChip && _showNextEpChip)
                      const SizedBox(
                        height: PlayerFloatingChipMetrics.stackGap,
                      ),
                    if (_showNextEpChip)
                      PlayerNextEpisodeChip(
                        countdown: _autoNextCountdown,
                        onCountdownComplete: _onAutoNextCountdownDone,
                        onCancel: _cancelAutoNext,
                        onPressed: () => unawaited(_nextEpisode()),
                      ),
                  ],
                ),
              ),
            if (!mini)
              DesktopWindowChrome.overlayDragStrip(
                showCaption: _controlsVisible,
              ),
          ],
        ),
      ),
    );
  }
}
