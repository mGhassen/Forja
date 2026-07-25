import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Android TV / leanback remote Back key - pop routes or focus active nav tab.
abstract final class ShellTvBackHandler {
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static void uninstall() {
    if (!_installed) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _installed = false;
  }

  static bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.goBack &&
        key != LogicalKeyboardKey.escape) {
      return false;
    }
    if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
      ShellTvFocusCoordinator.handleShellBackKey();
      return true;
    }
    return ShellTvFocusCoordinator.handleShellBackKey();
  }
}
