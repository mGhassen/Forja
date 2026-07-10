import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android TV: routes D-pad arrows through [FocusNode.focusInDirection] and logs
/// keys/focus in debug builds.
abstract final class TvRemoteDebug {
  static bool _installed = false;

  static void install() {
    if (_installed || !Platform.isAndroid) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    if (kDebugMode) {
      FocusManager.instance.addListener(_onFocusChange);
      debugPrint('[TV-KEY] debug handlers installed');
    }
  }

  static void uninstall() {
    if (!_installed) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (kDebugMode) {
      FocusManager.instance.removeListener(_onFocusChange);
    }
    _installed = false;
  }

  static String _focusLabel(FocusNode? node) {
    if (node == null) return 'null';
    if (node.debugLabel != null && node.debugLabel!.isNotEmpty) {
      return node.debugLabel!;
    }
    final ctx = node.context;
    if (ctx != null) return ctx.widget.runtimeType.toString();
    return 'FocusNode#${node.hashCode}';
  }

  static void _onFocusChange() {
    final primary = FocusManager.instance.primaryFocus;
    debugPrint(
      '[TV-FOCUS] primary=${_focusLabel(primary)} '
      'hasFocus=${primary?.hasFocus ?? false}',
    );
  }

  static TraversalDirection? _directionFor(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
  }

  static bool _onKey(KeyEvent event) {
    final primary = FocusManager.instance.primaryFocus;
    if (kDebugMode) {
      debugPrint(
        '[TV-KEY] ${event.runtimeType} '
        'logical=${event.logicalKey.keyLabel} '
        'physical=${event.physicalKey.usbHidUsage} '
        'focus=${_focusLabel(primary)}',
      );
    }

    if (event is! KeyDownEvent) return false;

    final direction = _directionFor(event.logicalKey);
    if (direction == null) return false;
    if (primary == null || primary.context == null) return false;

    final moved = primary.focusInDirection(direction);
    if (kDebugMode) {
      final group = FocusTraversalGroup.maybeOf(primary.context!);
      debugPrint(
        '[TV-FOCUS] focusInDirection($direction) moved=$moved '
        'traversalGroup=${group?.runtimeType} '
        'from=${_focusLabel(primary)} '
        'to=${_focusLabel(FocusManager.instance.primaryFocus)}',
      );
    }
    return moved;
  }
}
