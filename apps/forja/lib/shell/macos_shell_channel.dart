import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS native shell bridge — Edit → Find… (⌘F) lives in AppKit's menu bar
/// and never reaches Flutter unless rewired (see AppDelegate.openFind).
abstract final class MacOsShellChannel {
  static const _channel = MethodChannel('forja.macos/shell');

  static void listen({required VoidCallback onFind}) {
    if (kIsWeb || !Platform.isMacOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'find') onFind();
    });
  }

  static void dispose() {
    if (kIsWeb || !Platform.isMacOS) return;
    _channel.setMethodCallHandler(null);
  }
}
