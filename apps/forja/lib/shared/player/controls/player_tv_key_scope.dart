import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/controls/player_tv_remote.dart';

/// Captures leanback / D-pad keys inside a player route.
///
/// App-root [DirectionalFocusAction] (Android TV shell) otherwise consumes
/// arrows with no effect when focus is not on a shell catalog item.
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
  final Widget child;

  @override
  State<PlayerTvKeyScope> createState() => _PlayerTvKeyScopeState();
}

class _PlayerTvKeyScopeState extends State<PlayerTvKeyScope> {
  PlayerTvRemoteKeyHandler get _handler => PlayerTvRemoteKeyHandler(
        onBack: widget.onBack,
        onPlayPause: widget.onPlayPause,
        onShowControls: widget.onShowControls,
        onSeekBack: widget.onSeekBack,
        onSeekForward: widget.onSeekForward,
        onVolumeUp: widget.onVolumeUp,
        onVolumeDown: widget.onVolumeDown,
        onToggleControls: widget.onToggleControls,
      );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
    }
  }

  @override
  void didUpdateWidget(PlayerTvKeyScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) return;
    if (oldWidget.showControls && !widget.showControls) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
    }
  }

  void _claimFocus() {
    if (!mounted || !widget.enabled) return;
    if (widget.focusNode.canRequestFocus) {
      widget.focusNode.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (widget.showControls && playerTvChromeHasFocus(widget.focusNode)) {
      return KeyEventResult.ignored;
    }
    if (_handler.handle(event, showControls: widget.showControls)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

/// True when TV focus is on a player chrome control (not the video key scope).
bool playerTvChromeHasFocus(FocusNode playerKeyNode) {
  final primary = FocusManager.instance.primaryFocus;
  if (primary == null || identical(primary, playerKeyNode)) return false;
  FocusNode? node = primary;
  while (node != null) {
    if (node.debugLabel == 'player-chrome') return true;
    node = node.parent;
  }
  return false;
}
