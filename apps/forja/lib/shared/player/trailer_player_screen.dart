import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:rust/rust.dart';
import 'package:window_manager/window_manager.dart';

part 'trailer_player_web.dart';
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
    with _TrailerPlayerWeb, _TrailerPlayerMenus, _TrailerPlayerBuild {
  InAppWebViewController? _controller;
  late int _currentIndex;
  bool _playing = false;
  bool _ended = false;
  bool _muted = false;
  bool _ready = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  double _volume = 100;
  double _volumeBeforeMute = 100;
  String _selectedQuality = 'auto';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _hideTimer;
  final FocusNode _backFocus = FocusNode(debugLabel: 'trailer-back');
  final FocusNode _playFocus = FocusNode(debugLabel: 'trailer-play');
  final FocusNode _nextTrailerFocus = FocusNode(debugLabel: 'trailer-next');
  bool _tvFocus = false;
  bool _initialFocusClaimed = false;

  MediaTrailer get _trailer => widget.trailers[_currentIndex];

  bool get _hasNextTrailer => _currentIndex < widget.trailers.length - 1;

  bool get _showReplayControl => _ended && !_hasNextTrailer;

  bool get _hasMoreTrailers => widget.trailers.length > 1;

  /// Near end (≤15s) or finished — keep chrome up for More videos.
  bool get _showNextTrailerChip {
    if (!_hasMoreTrailers) return false;
    if (_ended) return true;
    if (_duration.inMilliseconds <= 0) return false;
    return (_duration - _position).inSeconds <= 15;
  }

  MediaTrailer get _moreVideosPreview {
    if (_hasNextTrailer) return widget.trailers[_currentIndex + 1];
    for (var i = 0; i < widget.trailers.length; i++) {
      if (i != _currentIndex) return widget.trailers[i];
    }
    return _trailer;
  }

  bool get _supportsWindowFullscreen =>
      !kIsWeb && DesktopWindowChrome.isDesktop;

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    ShellBus.notifyShellChromeChanged();
    _currentIndex = widget.initialIndex;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    if (!DesktopWindowChrome.isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (_supportsWindowFullscreen) {
      unawaited(_syncFullscreenState());
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    ShellBus.leavePlayerSurface();
    ShellBus.notifyShellChromeChanged();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _backFocus.dispose();
    _playFocus.dispose();
    _nextTrailerFocus.dispose();
    if (!DesktopWindowChrome.isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // TV keeps chrome visible; next-trailer / menus need chrome up.
    if (_tvFocus ||
        _ended ||
        _showNextTrailerChip ||
        PlayerPopupPanel.isShowing ||
        !_playing) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted ||
          _tvFocus ||
          _ended ||
          _showNextTrailerChip ||
          PlayerPopupPanel.isShowing) {
        return;
      }
      setState(() => _showControls = false);
    });
  }

  void _onPointerActivity() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
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
    if (PlayerPopupPanel.isShowing) {
      PlayerPopupPanel.dismiss();
      _claimPlayFocus();
      return;
    }
    if (_supportsWindowFullscreen && _isFullscreen) {
      await windowManager.setFullScreen(false);
      if (mounted) setState(() => _isFullscreen = false);
    }
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
