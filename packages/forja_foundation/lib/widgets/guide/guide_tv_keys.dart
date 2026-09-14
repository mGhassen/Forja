import 'package:flutter/services.dart';

/// D-pad navigation key — first press and OS key-repeat.
bool guideIsNavigationKey(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

/// Whether [key] is a TV activate key (Select / OK / Enter / Space).
bool guideIsActivateLogicalKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.numpadEnter;
}

/// Whether [event] is a TV activate key on KeyDown.
bool guideIsActivateKey(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  return guideIsActivateLogicalKey(event.logicalKey);
}
