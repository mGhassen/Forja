import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';

/// Debounced live URL probe — mirrors IPTV catalog lazy checks (350ms dwell).
/// Only live URLs land in [_sessionHealth]; misses are not cached across panels.
class IptvLazyUrlHealthProbe extends ChangeNotifier {
  IptvLazyUrlHealthProbe({
    this.delay = const Duration(milliseconds: 350),
    this.maxConcurrent = 2,
    this.onResult,
  });

  final Duration delay;
  final int maxConcurrent;
  final void Function(String key, bool ok)? onResult;

  static final Map<String, bool> _sessionHealth = {};

  final Map<String, bool> _health = {};
  final Set<String> _inFlight = {};
  final List<({String key, String url})> _queue = [];
  final Map<String, Timer> _debounce = {};
  bool _disposed = false;

  bool? healthFor(String key) => _health[key] ?? _sessionHealth[key];

  /// Immediate probe for Sources-panel hover check (skips dwell debounce).
  Future<bool> checkNow(String key, String url) async {
    final cached = healthFor(key);
    if (cached != null) return cached;
    if (_disposed) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    cancel(key);
    try {
      final ok = await IptvAliveChecker.checkOne(trimmed);
      if (_disposed) return ok;
      if (ok) {
        _health[key] = true;
        _sessionHealth[key] = true;
      } else {
        _health[key] = false;
        _sessionHealth.remove(key);
      }
      notifyListeners();
      onResult?.call(key, ok);
      return ok;
    } catch (_) {
      if (_disposed) return false;
      _health[key] = false;
      _sessionHealth.remove(key);
      notifyListeners();
      onResult?.call(key, false);
      return false;
    }
  }

  void schedule(String key, String url, {bool onlyThis = false}) {
    if (_disposed) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (_inFlight.contains(key)) return;

    if (onlyThis) {
      for (final id in _debounce.keys.toList()) {
        if (id == key) continue;
        _debounce[id]?.cancel();
        _debounce.remove(id);
      }
      _queue.removeWhere((x) => x.key != key);
    }

    _debounce[key]?.cancel();
    _debounce[key] = Timer(delay, () {
      _debounce.remove(key);
      _enqueue(key, trimmed);
    });
  }

  void cancel(String key) {
    _debounce[key]?.cancel();
    _debounce.remove(key);
    _queue.removeWhere((x) => x.key == key);
  }

  void cancelAll() {
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
    _queue.clear();
  }

  void _enqueue(String key, String url) {
    if (_disposed || _inFlight.contains(key)) return;
    if (_inFlight.length >= maxConcurrent) {
      if (!_queue.any((x) => x.key == key)) {
        _queue.add((key: key, url: url));
      }
      return;
    }
    unawaited(_run(key, url));
  }

  Future<void> _run(String key, String url) async {
    if (_disposed) return;
    _inFlight.add(key);
    try {
      final ok = await IptvAliveChecker.checkOne(url);
      if (_disposed) return;
      if (ok) {
        if (_health[key] == true && _sessionHealth[key] == true) return;
        _health[key] = true;
        _sessionHealth[key] = true;
      } else {
        if (_health[key] == false) return;
        _health[key] = false;
        _sessionHealth.remove(key);
      }
      notifyListeners();
      onResult?.call(key, ok);
    } catch (_) {
      if (_disposed) return;
      if (_health[key] == false) return;
      _health[key] = false;
      _sessionHealth.remove(key);
      notifyListeners();
      onResult?.call(key, false);
    } finally {
      _inFlight.remove(key);
      _drain();
    }
  }

  void _drain() {
    while (_queue.isNotEmpty && _inFlight.length < maxConcurrent) {
      final next = _queue.removeAt(0);
      if (!_inFlight.contains(next.key)) {
        unawaited(_run(next.key, next.url));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancelAll();
    super.dispose();
  }
}
