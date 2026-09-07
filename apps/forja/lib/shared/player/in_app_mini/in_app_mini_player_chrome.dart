import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Corner chrome for in-Forja mini player: Play/Pause, Expand, Close.
///
/// Auto-hides after idle (same 3s as desktop full-player chrome). Hover, tap,
/// or D-pad focus on the mini reveals it again.
///
/// Never calls OS/window PiP ([PipService]).
class InAppMiniPlayerChrome extends StatefulWidget {
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

  /// Default corner size (also [InAppMiniPlayerController.defaultSize]).
  static const double width = 320;
  static const double height = 180;

  static const Duration hideAfter = Duration(seconds: 3);

  @override
  State<InAppMiniPlayerChrome> createState() => _InAppMiniPlayerChromeState();
}

class _InAppMiniPlayerChromeState extends State<InAppMiniPlayerChrome> {
  bool _chromeVisible = true;
  Timer? _hideTimer;

  bool get _anyMiniFocused =>
      widget.rootFocus.hasFocus ||
      widget.playPauseFocus.hasFocus ||
      widget.expandFocus.hasFocus ||
      widget.closeFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _listenFocus(true);
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant InAppMiniPlayerChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rootFocus, widget.rootFocus) ||
        !identical(oldWidget.playPauseFocus, widget.playPauseFocus) ||
        !identical(oldWidget.expandFocus, widget.expandFocus) ||
        !identical(oldWidget.closeFocus, widget.closeFocus)) {
      _listenFocus(false, old: oldWidget);
      _listenFocus(true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _listenFocus(false);
    super.dispose();
  }

  void _listenFocus(bool add, {InAppMiniPlayerChrome? old}) {
    final w = old ?? widget;
    final nodes = [
      w.rootFocus,
      w.playPauseFocus,
      w.expandFocus,
      w.closeFocus,
    ];
    for (final n in nodes) {
      if (add) {
        n.addListener(_onFocusChanged);
      } else {
        n.removeListener(_onFocusChanged);
      }
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_anyMiniFocused) {
      _reveal();
    } else {
      _scheduleHide();
    }
  }

  void _reveal() {
    _hideTimer?.cancel();
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
    if (!_anyMiniFocused) {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_anyMiniFocused) return;
    _hideTimer = Timer(InAppMiniPlayerChrome.hideAfter, () {
      if (!mounted || _anyMiniFocused) return;
      setState(() => _chromeVisible = false);
    });
  }

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
      focusNode: widget.rootFocus,
      onKeyEvent: _onRootKey,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        // Transparent — parent Material clips/elevates the video slot.
        // Opaque black here covered MediaKit/Exo (audio-only mini).
        child: Material(
          type: MaterialType.transparency,
          child: MouseRegion(
            onEnter: (_) => _reveal(),
            onHover: (_) => _reveal(),
            onExit: (_) {
              if (!_anyMiniFocused) _scheduleHide();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _reveal,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    right: 4,
                    top: 4,
                    child: AnimatedOpacity(
                      opacity: _chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: IgnorePointer(
                        ignoring: !_chromeVisible,
                        child: _MiniFocusButton(
                          focusNode: widget.closeFocus,
                          order: 3,
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: widget.onClose,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: _chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: IgnorePointer(
                        ignoring: !_chromeVisible,
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
                                  focusNode: widget.playPauseFocus,
                                  order: 1,
                                  icon: widget.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  tooltip: widget.playing ? 'Pause' : 'Play',
                                  onTap: widget.onPlayPause,
                                ),
                                const Spacer(),
                                _MiniFocusButton(
                                  focusNode: widget.expandFocus,
                                  order: 2,
                                  icon: Icons.open_in_full_rounded,
                                  tooltip: 'Expand',
                                  onTap: widget.onExpand,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
