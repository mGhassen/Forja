import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_tv_remote.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Captures leanback / D-pad keys inside a player route.
///
/// App-root [DirectionalFocusAction] (Android TV shell) otherwise consumes
/// arrows with no effect when focus is not on a shell catalog item.
///
/// While chrome is hidden, a [HardwareKeyboard] handler owns ←/→ seek so keys
/// still work even if focus claim races with [ExcludeFocus]. While chrome is
/// visible, ←/→ never seek from this scope — only chrome focus traversal or
/// the focused progress bar moves position.
class PlayerTvKeyScope extends StatefulWidget {
  const PlayerTvKeyScope({
    super.key,
    required this.enabled,
    required this.focusNode,
    required this.showControls,
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
    this.onControlsActivity,
    required this.child,
  });

  final bool enabled;
  final FocusNode focusNode;
  final bool showControls;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onShowControls;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;
  final VoidCallback onToggleControls;
  /// D-pad ↑ while chrome is not focused — show chrome and focus Back.
  final VoidCallback onFocusBack;
  /// D-pad ↓ while chrome is not focused — show chrome and focus Play.
  final VoidCallback onFocusPlay;
  /// Fired on D-pad / remote keys while chrome is visible so auto-hide can
  /// restart from idle (focus traversal alone does not touch the timer).
  final VoidCallback? onControlsActivity;
  final Widget child;

  @override
  State<PlayerTvKeyScope> createState() => _PlayerTvKeyScopeState();
}

class _PlayerTvKeyScopeState extends State<PlayerTvKeyScope> {
  bool _ensureFocusScheduled = false;

  PlayerTvRemoteKeyHandler get _handler => PlayerTvRemoteKeyHandler(
        onBack: widget.onBack,
        onPlayPause: widget.onPlayPause,
        onShowControls: widget.onShowControls,
        onSeekBack: widget.onSeekBack,
        onSeekForward: widget.onSeekForward,
        onVolumeUp: widget.onVolumeUp,
        onVolumeDown: widget.onVolumeDown,
        onToggleControls: widget.onToggleControls,
        onFocusBack: widget.onFocusBack,
        onFocusPlay: widget.onFocusPlay,
      );

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    FocusManager.instance.addListener(_onGlobalFocusChange);
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocus());
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChange);
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  @override
  void didUpdateWidget(PlayerTvKeyScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) return;
    if (oldWidget.showControls != widget.showControls) {
      _scheduleEnsureFocus();
    }
  }

  void _onGlobalFocusChange() {
    if (!widget.enabled) return;
    _scheduleEnsureFocus();
  }

  void _scheduleEnsureFocus() {
    if (_ensureFocusScheduled) return;
    _ensureFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFocusScheduled = false;
      _ensureFocus();
    });
  }

  /// Chrome visible + empty / video-key focus → Play. Chrome hidden + empty →
  /// video key node (seek / OK still work after idle hide).
  void _ensureFocus() {
    if (!mounted || !widget.enabled) return;
    // Menus (stats, settings, …) own D-pad — do not yank focus under an overlay.
    if (playerChromeOverlayBlocksFocusClaim()) return;
    final primary = FocusManager.instance.primaryFocus;
    final lost = primary == null || !primary.hasFocus;
    if (widget.showControls) {
      if (lost || identical(primary, widget.focusNode)) {
        widget.onFocusPlay();
      }
      return;
    }
    if (lost && widget.focusNode.canRequestFocus) {
      widget.focusNode.requestFocus();
    }
  }

  /// Chrome hidden: handle remote keys even when focus claim lost the race to
  /// app-root [DirectionalFocusAction] (←/→ otherwise no-op).
  ///
  /// Chrome visible: do not consume — only ping [onControlsActivity]. Focused
  /// [FocusableControl] returns [KeyEventResult.handled] for arrows, so the
  /// Focus [onKeyEvent] never sees them and auto-hide would fire mid-nav.
  bool _onHardwareKey(KeyEvent event) {
    if (!widget.enabled) return false;
    if (!shellTvIsNavigationKey(event)) return false;
    if (widget.showControls) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        widget.onControlsActivity?.call();
      }
      return false;
    }
    if (playerChromeOverlayBlocksSeek()) return false;
    return _handler.handle(event, showControls: false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    // Any remote key while chrome is up counts as activity (incl. D-pad
    // traversal over focused buttons, which otherwise never resets hide).
    if (widget.showControls && shellTvIsNavigationKey(event)) {
      widget.onControlsActivity?.call();
    }
    // Volume keys must win even while a chrome control holds focus.
    if (shellTvIsNavigationKey(event)) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.audioVolumeUp) {
        widget.onVolumeUp();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.audioVolumeDown) {
        widget.onVolumeDown();
        return KeyEventResult.handled;
      }
    }
    if (widget.showControls && playerTvChromeHasFocus(widget.focusNode)) {
      return KeyEventResult.ignored;
    }
    // Chrome visible but focus not on a control (race / platform view): ←/→
    // must restore chrome focus — never seek. Progress-bar seek only when the
    // bar itself holds focus (handled above via FocusableControl / seekbar).
    if (widget.showControls && shellTvIsNavigationKey(event)) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        widget.onFocusPlay();
        return KeyEventResult.handled;
      }
    }
    // Chrome hidden: [_onHardwareKey] already handled navigation keys.
    if (!widget.showControls && shellTvIsNavigationKey(event)) {
      return KeyEventResult.handled;
    }
    if (_handler.handle(event, showControls: widget.showControls)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    // When chrome is hidden, only this node may hold focus. Otherwise an
    // invisible Play / Sources control can keep primary focus and FocusableControl
    // eats ←/→ as traversal instead of seeking.
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      descendantsAreFocusable: widget.showControls,
      descendantsAreTraversable: widget.showControls,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

/// True when TV focus is on chrome or a floating menu (not the video key scope).
bool playerTvChromeHasFocus(FocusNode playerKeyNode) {
  final primary = FocusManager.instance.primaryFocus;
  if (primary == null || identical(primary, playerKeyNode)) return false;
  FocusNode? node = primary;
  while (node != null) {
    final label = node.debugLabel;
    if (label == 'player-chrome' ||
        label == 'exo-player-chrome' ||
        label == 'player-tv-menu') {
      return true;
    }
    node = node.parent;
  }
  return false;
}
