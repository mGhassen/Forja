import 'dart:async';
import 'dart:convert';

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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final FocusNode _backFocus = FocusNode(debugLabel: 'trailer-back');
  final FocusNode _playFocus = FocusNode(debugLabel: 'trailer-play');
  final FocusNode _nextTrailerFocus = FocusNode(debugLabel: 'trailer-next');
  bool _tvFocus = false;
  bool _initialFocusClaimed = false;

  MediaTrailer get _trailer => widget.trailers[_currentIndex];

  bool get _hasNextTrailer => _currentIndex < widget.trailers.length - 1;

  MediaTrailer? get _nextTrailer =>
      _hasNextTrailer ? widget.trailers[_currentIndex + 1] : null;

  bool get _showReplayControl => _ended && _hasNextTrailer;

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    _currentIndex = widget.initialIndex;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    ShellBus.leavePlayerSurface();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _backFocus.dispose();
    _playFocus.dispose();
    _nextTrailerFocus.dispose();
    super.dispose();
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
    if (!_tvFocus || !_ended || !_hasNextTrailer) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_nextTrailerFocus.canRequestFocus) return;
      _nextTrailerFocus.requestFocus();
    });
  }

  void _exitTrailer() {
    if (PlayerPopupPanel.isShowing) {
      PlayerPopupPanel.dismiss();
      _claimPlayFocus();
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_tvFocus) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    _exitTrailer();
    return true;
  }
}
