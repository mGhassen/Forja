import 'package:flutter/services.dart';

/// Stack of back handlers for the topmost [BackNavigationScope].
/// macOS trackpad swipe is delivered via platform channel from the embedder.
class NavigationBackHandler {
  NavigationBackHandler._();

  static const _channel = MethodChannel('forja/navigation');
  static final List<VoidCallback> _stack = <VoidCallback>[];
  static bool _installed = false;

  static void ensureInstalled() {
    if (_installed) return;
    _installed = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trackpadBack' && _stack.isNotEmpty) {
        _stack.last();
      }
    });
  }

  static void push(VoidCallback onBack) {
    ensureInstalled();
    _stack.add(onBack);
  }

  static void pop(VoidCallback onBack) {
    if (_stack.isEmpty) return;
    if (_stack.last == onBack) {
      _stack.removeLast();
      return;
    }
    _stack.remove(onBack);
  }
}
