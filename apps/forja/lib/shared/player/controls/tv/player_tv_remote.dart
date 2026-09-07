import 'package:flutter/services.dart';
import 'package:forja/shared/foundation/tv/shell_tv_focus.dart';

/// D-pad / leanback remote key handling for [MobilePlayerScreen] TV mode.
class PlayerTvRemoteKeyHandler {
  const PlayerTvRemoteKeyHandler({
    required this.onBack,
    required this.onPlayPause,
    required this.onShowControls,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleControls,
    required this.onFocusBack,
    required this.onFocusPlay,
  });

  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onShowControls;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleControls;
  /// Chrome hidden / video key scope: D-pad ↑ → Back button.
  final VoidCallback onFocusBack;
  /// Chrome hidden / video key scope: D-pad ↓ → Play button.
  final VoidCallback onFocusPlay;

  bool handle(KeyEvent event, {required bool showControls}) {
    if (!shellTvIsNavigationKey(event)) return false;

    final key = event.logicalKey;

    // Volume Up/Down: never consume — leanback chrome has no volume control;
    // Android must own STREAM_MUSIC / HDMI-CEC so the OS OSD works.

    if (key == LogicalKeyboardKey.goBack) {
      onBack();
      return true;
    }
    // Escape is remote Exit on ATV — do not steal it as Back. ShellTvBackHandler
    // maps Escape → handleShellExitKey (double-confirm quit).

    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10) {
      onToggleControls();
      return true;
    }

    // Space / media play-pause: toggle only — never reveal chrome.
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      onPlayPause();
      return true;
    }

    // OK / Enter: show chrome when hidden, else play/pause (focus owns buttons).
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
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
