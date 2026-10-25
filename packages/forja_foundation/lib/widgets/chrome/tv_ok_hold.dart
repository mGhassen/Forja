import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forja_foundation/tokens/card_quick_menu_tokens.dart';

/// Leanback OK-hold / MENU secondary action (same contract as catalog posters).
///
/// OK **down** starts [duration]; hold fires [onHold]. OK **up** before the
/// timer ends runs the short [onTap] instead. MENU fires [onHold] immediately.
final class TvOkHold {
  TvOkHold({
    required this.onHold,
    this.duration = CardQuickMenuTokens.holdDelay,
  });

  final VoidCallback onHold;
  final Duration duration;

  Timer? _timer;
  bool _fired = false;
  LogicalKeyboardKey? _activateKey;

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _activateKey = null;
  }

  /// Wrap [onTap] so a completed hold does not also activate.
  VoidCallback wrapTap(VoidCallback onTap) {
    return () {
      if (_fired) {
        _fired = false;
        return;
      }
      onTap();
    };
  }

  /// Pointer long-press — marks fired so a following tap is swallowed.
  void fireFromPointer() {
    _cancel();
    _fired = true;
    onHold();
  }

  /// MENU / context-menu — no OK key-up follows, so do not arm the tap swallow.
  void fireFromMenu() {
    _cancel();
    _fired = false;
    onHold();
  }

  KeyEventResult onKeyEvent(KeyEvent event, {required VoidCallback onShort}) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent) fireFromMenu();
      return KeyEventResult.handled;
    }
    final activate =
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    if (!activate) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _activateKey = event.logicalKey;
      _start();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent && _activateKey == event.logicalKey) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent && _activateKey == event.logicalKey) {
      final fired = _fired;
      _cancel();
      if (!fired) onShort();
      _fired = false;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _start() {
    _timer?.cancel();
    _fired = false;
    _timer = Timer(duration, () {
      _fired = true;
      onHold();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _activateKey = null;
  }
}
