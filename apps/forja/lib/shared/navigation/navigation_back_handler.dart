import 'package:flutter/services.dart';

/// macOS trackpad swipe-back → Dart.
///
/// Native [NSEvent] `.swipe` is delivered on [MethodChannel] `forja/navigation`
/// as `trackpadBack`. Bound from the app-wide [BackNavigationScope].
class NavigationBackHandler {
  NavigationBackHandler._();

  static const _channel = MethodChannel('forja/navigation');
  static VoidCallback? _onBack;
  static bool _installed = false;
  static DateTime? _lastInvokedAt;

  /// Ignore duplicate swipe events within this window (trackpad fires bursts).
  static const _debounce = Duration(milliseconds: 450);

  static void ensureInstalled() {
    if (_installed) return;
    _installed = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'trackpadBack') return;
      final now = DateTime.now();
      final last = _lastInvokedAt;
      if (last != null && now.difference(last) < _debounce) return;
      _lastInvokedAt = now;
      _onBack?.call();
    });
  }

  static void bind(VoidCallback onBack) {
    ensureInstalled();
    _onBack = onBack;
  }

  static void unbind(VoidCallback onBack) {
    if (_onBack == onBack) _onBack = null;
  }
}
