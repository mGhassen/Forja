import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Corner chrome for in-Forja mini player: Play/Pause, Expand, Close.
///
/// Never calls OS/window PiP ([PipService]).
class InAppMiniPlayerChrome extends StatelessWidget {
  const InAppMiniPlayerChrome({
    super.key,
    required this.playing,
    required this.rootFocus,
    required this.playPauseFocus,
    required this.expandFocus,
    required this.closeFocus,
    this.onPlayPause,
    this.onExpand,
    this.onClose,
  });

  final bool playing;
  final FocusNode rootFocus;
  final FocusNode playPauseFocus;
  final FocusNode expandFocus;
  final FocusNode closeFocus;
  final VoidCallback? onPlayPause;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;

  static const double width = 320;
  static const double height = 180;

  KeyEventResult _onRootKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack) {
      // Back / leave focus — not Close. Escape while mini closes via player.
      if (key == LogicalKeyboardKey.escape) {
        return KeyEventResult.ignored;
      }
      InAppMiniPlayerController.instance.restoreChromeFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: rootFocus,
      onKeyEvent: _onRootKey,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        // Transparent — parent Material clips/elevates the video slot.
        // Opaque black here covered MediaKit/Exo (audio-only mini).
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                    child: Row(
                      children: [
                        _MiniFocusButton(
                          focusNode: playPauseFocus,
                          order: 1,
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: playing ? 'Pause' : 'Play',
                          onTap: onPlayPause,
                        ),
                        const Spacer(),
                        _MiniFocusButton(
                          focusNode: expandFocus,
                          order: 2,
                          icon: Icons.open_in_full_rounded,
                          tooltip: 'Expand',
                          onTap: onExpand,
                        ),
                        const SizedBox(width: 6),
                        _MiniFocusButton(
                          focusNode: closeFocus,
                          order: 3,
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniFocusButton extends StatelessWidget {
  const _MiniFocusButton({
    required this.focusNode,
    required this.order,
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final FocusNode focusNode;
  final double order;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: FocusableControl(
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: 8,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
