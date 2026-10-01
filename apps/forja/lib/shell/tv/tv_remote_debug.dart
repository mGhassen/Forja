import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android TV: logs D-pad keys and focus changes in debug builds.
abstract final class TvRemoteDebug {
  static bool _installed = false;

  static void install() {
    if (_installed || !Platform.isAndroid) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    if (kDebugMode) {
      FocusManager.instance.addListener(_onFocusChange);
      debugPrint('[TV-KEY] debug handlers installed (log only)');
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

  static bool _onKey(KeyEvent event) {
    if (!kDebugMode) return false;
    final primary = FocusManager.instance.primaryFocus;
    debugPrint(
      '[TV-KEY] ${event.runtimeType} '
      'logical=${event.logicalKey.keyLabel} '
      'physical=${event.physicalKey.usbHidUsage} '
      'focus=${_focusLabel(primary)}',
    );
    return false;
  }
}
