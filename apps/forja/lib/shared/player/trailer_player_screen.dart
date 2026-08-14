import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/services/youtube_stream_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:rust/rust.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

part 'trailer_player_playback.dart';
part 'trailer_player_menus.dart';
part 'trailer_player_build.dart';

class TrailerPlayerScreen extends StatefulWidget {
  const TrailerPlayerScreen({
    super.key,
    required this.trailers,
    required this.initialIndex,
    this.movie,
    this.languageCode,
  });

  final List<MediaTrailer> trailers;
  final int initialIndex;
  final Movie? movie;
  final String? languageCode;

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen>
    with _TrailerPlayerPlayback, _TrailerPlayerMenus, _TrailerPlayerBuild {
  Player? _player;
  VideoController? _controller;
  YoutubeResolvedStreams? _streams;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;
  int _loadGeneration = 0;

  late int _currentIndex;
  bool _playing = false;
  bool _ended = false;
  bool _muted = false;
  bool _ready = false;
  bool _resolving = false;
  String? _resolveError;
  bool _isFullscreen = false;
  bool _showControls = true;
  double _volume = 100;
  double _volumeBeforeMute = 100;
  double _playbackRate = 1.0;
  int? _selectedQualityHeight;
  String? _activeCaptionCode;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _hideTimer;
  Timer? _autoNextTick;
  int? _autoNextSecondsLeft;
  final FocusNode _backFocus = FocusNode(debugLabel: 'trailer-back');
  final FocusNode _playFocus = FocusNode(debugLabel: 'trailer-play');
  final FocusNode _rewindFocus = FocusNode(debugLabel: 'trailer-rewind');
  final FocusNode _forwardFocus = FocusNode(debugLabel: 'trailer-forward');
  final FocusNode _subsFocus = FocusNode(debugLabel: 'trailer-subs');
  final FocusNode _qualityFocus = FocusNode(debugLabel: 'trailer-quality');
  final FocusNode _speedFocus = FocusNode(debugLabel: 'trailer-speed');
  final FocusNode _playerMenuFocus = FocusNode(debugLabel: 'trailer-player-menu');
  final FocusNode _nextTrailerFocus = FocusNode(debugLabel: 'trailer-next');
  final FocusNode _seekbarFocus = FocusNode(debugLabel: 'trailer-seekbar');
  final FocusNode _tvKeyFocus = FocusNode(debugLabel: 'trailer-player-tv-keys');
  /// First TV Back hid chrome (or armed while hidden) — next Back exits.
  bool _tvBackExitArmed = false;
  bool _tvFocus = false;
  bool _initialFocusClaimed = false;
  late int _pickerIndex;

  static const int _autoNextSeconds = 5;

  MediaTrailer get _trailer => widget.trailers[_currentIndex];

  bool get _hasNextTrailer => _currentIndex < widget.trailers.length - 1;

  bool get _showReplayControl => _ended && !_hasNextTrailer;

  bool get _hasMoreTrailers => widget.trailers.length > 1;

  bool get _autoNextActive => _autoNextSecondsLeft != null;

  /// Near end (≤15s) or finished - keep chrome up for More videos.
  bool get _showNextTrailerChip {
    if (!_hasMoreTrailers) return false;
    if (_ended) return true;
    if (_duration.inMilliseconds <= 0) return false;
    return (_duration - _position).inSeconds <= 15;
  }

  MediaTrailer get _pickerTrailer => widget.trailers[_pickerIndex];

  int _pickerIndexAfter(int playingIndex) {
    final n = widget.trailers.length;
    if (n <= 1) return playingIndex;
    if (playingIndex < n - 1) return playingIndex + 1;
    return 0;
  }

  void _cancelAutoNext({bool rebuild = true}) {
    _autoNextTick?.cancel();
    _autoNextTick = null;
    if (_autoNextSecondsLeft == null) return;
    if (rebuild && mounted) {
      setState(() => _autoNextSecondsLeft = null);
    } else {
      _autoNextSecondsLeft = null;
    }
  }

  void _maybeStartAutoNext() {
    _cancelAutoNext(rebuild: false);
    if (!_ended || !_hasNextTrailer) return;
    final next = _currentIndex + 1;
    setState(() {
      _pickerIndex = next;
      _autoNextSecondsLeft = _autoNextSeconds;
      _showControls = true;
    });
    _focusNextTrailerIfNeeded();
    _autoNextTick = Timer.periodic(const Duration(seconds: 1), (tick) {
      if (!mounted) {
        tick.cancel();
        return;
      }
      final left = (_autoNextSecondsLeft ?? 1) - 1;
      if (left <= 0) {
        tick.cancel();
        _autoNextTick = null;
        _autoNextSecondsLeft = null;
        _playTrailerAt(next);
        return;
      }
      setState(() => _autoNextSecondsLeft = left);
    });
  }

  void _shiftPicker(int delta) {
    final n = widget.trailers.length;
    if (n <= 1) return;
    _cancelAutoNext();
    var next = (_pickerIndex + delta) % n;
    if (next < 0) next += n;
    if (next == _pickerIndex) return;
    setState(() => _pickerIndex = next);
    _onPointerActivity();
  }

  bool get _supportsWindowFullscreen =>
      !kIsWeb && DesktopWindowChrome.isDesktop;

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    _currentIndex = widget.initialIndex;
    _pickerIndex = _pickerIndexAfter(_currentIndex);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    PlayerBackExitGate.setTryFocusBack(() {
      if (!mounted) return false;
      return PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: _showControls,
        armed: _tvBackExitArmed,
        hideChrome: () {
          _hideTimer?.cancel();
          setState(() => _showControls = false);
        },
        setArmed: (v) => _tvBackExitArmed = v,
      );
    });
    if (!DesktopWindowChrome.isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (_supportsWindowFullscreen) {
      unawaited(_syncFullscreenState());
    }
    _startHideTimer();
    unawaited(_loadCurrentTrailer());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _cancelAutoNext(rebuild: false);
    _loadGeneration++;
    unawaited(_teardownPlayer());
    ShellBus.leavePlayerSurface();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    PlayerBackExitGate.setTryFocusBack(null);
    _backFocus.dispose();
    _playFocus.dispose();
    _rewindFocus.dispose();
    _forwardFocus.dispose();
    _subsFocus.dispose();
    _qualityFocus.dispose();
    _speedFocus.dispose();
    _playerMenuFocus.dispose();
    _nextTrailerFocus.dispose();
    _seekbarFocus.dispose();
    _tvKeyFocus.dispose();
    if (!DesktopWindowChrome.isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_playing) return;
    if (_ended || _autoNextActive || _showNextTrailerChip) return;
    if (playerChromeOverlayBlocksSeek()) return;
    final hideAfter =
        _tvFocus ? const Duration(seconds: 10) : const Duration(seconds: 3);
    _hideTimer = Timer(hideAfter, () {
      if (!mounted || !_playing) return;
      if (_ended || _autoNextActive || _showNextTrailerChip) return;
      if (playerChromeOverlayBlocksSeek()) {
        _startHideTimer();
        return;
      }
      if (_tvFocus && playerTvChromeHasFocus(_tvKeyFocus)) {
        _startHideTimer();
        return;
      }
      setState(() => _showControls = false);
    });
  }

  void _onPointerActivity() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  void _showChromeAndFocusPlay() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
    _claimPlayFocus();
  }

  void _showChromeAndFocusBack() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_backFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _backFocus.requestFocus();
    });
  }

  void _focusSeekbar() {
    if (!_seekbarFocus.canRequestFocus) return;
    _seekbarFocus.requestFocus();
  }

  void _focusDownFromBack() {
    if (_hasMoreTrailers && _nextTrailerFocus.canRequestFocus) {
      _nextTrailerFocus.requestFocus();
      return;
    }
    _focusSeekbar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv == _tvFocus) return;
    _tvFocus = tv;
    if (tv && !_initialFocusClaimed) {
      _initialFocusClaimed = true;
      _claimPlayFocus();
    }
  }

  void _claimPlayFocus() {
    if (!_tvFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _playFocus.requestFocus();
    });
  }

  void _focusNextTrailerIfNeeded() {
    if (!_tvFocus || !_hasMoreTrailers || !_showNextTrailerChip) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_nextTrailerFocus.canRequestFocus) return;
      _nextTrailerFocus.requestFocus();
    });
  }

  Future<void> _syncFullscreenState() async {
    if (!_supportsWindowFullscreen) return;
    final isFull = await windowManager.isFullScreen();
    if (!mounted || isFull == _isFullscreen) return;
    setState(() => _isFullscreen = isFull);
  }

  Future<void> _toggleFullscreen() async {
    if (!_supportsWindowFullscreen) return;
    final isFull = await windowManager.isFullScreen();
    if (!isFull && await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    await windowManager.setFullScreen(!isFull);
    if (mounted) setState(() => _isFullscreen = !isFull);
  }

  Future<void> _exitTrailer() async {
    if (dismissAnyPlayerChromeOverlay()) {
      _claimPlayFocus();
      return;
    }
    if (_supportsWindowFullscreen && _isFullscreen) {
      await windowManager.setFullScreen(false);
      if (mounted) setState(() => _isFullscreen = false);
    }
    await _teardownPlayer();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_tvFocus) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    unawaited(_exitTrailer());
    return true;
  }
}
