import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS native shell bridge - AppKit menu / terminate hooks that never reach
/// Flutter unless rewired (see `AppDelegate`).
abstract final class MacOsShellChannel {
  static const _channel = MethodChannel('forja.macos/shell');

  static VoidCallback? _onFind;
  static Future<void> Function()? _onPrepareQuit;
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (kIsWeb || !Platform.isMacOS) return;
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'find':
          _onFind?.call();
          break;
        case 'prepareQuit':
          await _onPrepareQuit?.call();
          break;
      }
    });
  }

  /// Edit → Find… (⌘F). Safe to call from [MainScreen]; does not clear quit.
  static void listen({required VoidCallback onFind}) {
    if (kIsWeb || !Platform.isMacOS) return;
    _onFind = onFind;
    _ensureHandler();
  }

  /// ⌘Q / Quit menu - AppKit asks Flutter to tear down mpv before terminate.
  static void listenPrepareQuit(Future<void> Function() onPrepareQuit) {
    if (kIsWeb || !Platform.isMacOS) return;
    _onPrepareQuit = onPrepareQuit;
    _ensureHandler();
  }

  /// Tell AppKit teardown finished - [applicationShouldTerminate] may proceed.
  static Future<void> replyReadyToTerminate() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('replyReadyToTerminate');
    } catch (_) {}
  }

  /// Drop Find only - keep [prepareQuit] for app quit after [MainScreen] unmounts.
  static void dispose() {
    _onFind = null;
  }
}
