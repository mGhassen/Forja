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
    required this.onFocusBack,
    required this.onFocusPlay,
  });

  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onShowControls;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;
  final VoidCallback onToggleControls;
  /// Chrome hidden / video key scope: D-pad ↑ → Back button.
  final VoidCallback onFocusBack;
  /// Chrome hidden / video key scope: D-pad ↓ → Play button.
  final VoidCallback onFocusPlay;

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

    // Dedicated transport keys always seek. D-pad ←/→ seek only while chrome
    // is hidden — when chrome is up, [PlayerTvKeyScope] / FocusableControl /
    // the progress bar own left/right (never skip from the video key node).
    if (key == LogicalKeyboardKey.mediaRewind) {
      onSeekBack();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      onSeekForward();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (showControls) return false;
      onSeekBack();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (showControls) return false;
      onSeekForward();
      return true;
    }

    // Chrome visible: FocusableControl / seekbar own ↑/↓ — never reclaim Back/Play
    // from the video key scope (that traps focus on Play).
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      if (showControls) return false;
      if (key == LogicalKeyboardKey.arrowUp) {
        onFocusBack();
      } else {
        onFocusPlay();
      }
      return true;
    }

    return false;
  }
}
