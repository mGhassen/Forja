import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// D-pad / leanback remote key handling for [MobilePlayerScreen] TV mode.
class PlayerTvRemoteKeyHandler {
  const PlayerTvRemoteKeyHandler({
    required this.onBack,
    required this.onPlayPause,
    required this.onShowControls,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onVolumeUp,
    required this.onVolumeDown,
    required this.onToggleControls,
  });

  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onShowControls;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;
  final VoidCallback onToggleControls;

  bool handle(KeyEvent event, {required bool showControls}) {
    if (!shellTvIsNavigationKey(event)) return false;

    final key = event.logicalKey;

    // Hardware remote volume - always, even when chrome is focused.
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      onVolumeUp();
      return true;
    }
    if (key == LogicalKeyboardKey.audioVolumeDown) {
      onVolumeDown();
      return true;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      onBack();
      return true;
    }

    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10) {
      onToggleControls();
      return true;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (!showControls) {
        onShowControls();
      } else {
        onPlayPause();
      }
      return true;
    }

    if (showControls &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.mediaRewind ||
            key == LogicalKeyboardKey.mediaFastForward)) {
      return false;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      onSeekBack();
      return true;
    }

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      onSeekForward();
      return true;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      onVolumeUp();
      return true;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      onVolumeDown();
      return true;
    }

    return false;
  }
}
