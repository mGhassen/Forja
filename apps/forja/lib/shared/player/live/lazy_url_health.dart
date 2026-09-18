import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/player/sources/resolve_streams_hooks.dart';

/// Debounced live URL probe — mirrors IPTV catalog lazy checks (350ms dwell).
/// Fresh results skip re-probe for [ttl] (stale-while-revalidate paint stays).
/// Only alive URLs land in [_sessionHealth]; misses stay instance-local.
class LazyUrlHealthProbe extends ChangeNotifier
    implements KitUrlHealthProbe {
  LazyUrlHealthProbe({
    this.delay = const Duration(milliseconds: 350),
    this.maxConcurrent = 2,
    this.ttl = const Duration(minutes: 2),
    this.onResult,
  });

  final Duration delay;
  final int maxConcurrent;
  final Duration ttl;
  final void Function(String key, bool ok)? onResult;

  static final Map<String, bool> _sessionHealth = {};
  static final Map<String, DateTime> _sessionCheckedAt = {};

  final Map<String, bool> _health = {};
  final Map<String, DateTime> _checkedAt = {};
  final Map<String, ValueNotifier<bool?>> _listenables = {};
  final Set<String> _inFlight = {};
  final List<({String key, String url})> _queue = [];
  final Map<String, Timer> _debounce = {};
  bool _disposed = false;

  @override
  bool? healthFor(String key) => _health[key] ?? _sessionHealth[key];

  /// True when [healthFor] is set and last check is inside [ttl].
  bool isFresh(String key) {
    final k = key.trim();
    if (k.isEmpty || healthFor(k) == null) return false;
    final at = _checkedAt[k] ?? _sessionCheckedAt[k];
    if (at == null) return false;
    return DateTime.now().difference(at) < ttl;
  }

  /// Per-key listenable — catalog cards subscribe so one probe does not rebuild
  /// the whole grid ([ChangeNotifier] still fires for short picker lists).
  ValueListenable<bool?> listenableFor(String key) {
    final k = key.trim();
    return _listenables.putIfAbsent(
      k,
      () => ValueNotifier<bool?>(healthFor(k)),
    );
  }

  void _publish(String key, bool ok) {
    final n = _listenables[key];
    if (n != null && n.value != ok) n.value = ok;
  }

  void _markChecked(String key) {
    final now = DateTime.now();
    _checkedAt[key] = now;
    _sessionCheckedAt[key] = now;
  }

  /// Cache a probe result from a header-aware check (no URL re-fetch).
  @override
  void remember(String key, bool ok) {
    if (_disposed) return;
    final k = key.trim();
    if (k.isEmpty) return;
    if (ok) {
      _health[k] = true;
      _sessionHealth[k] = true;
    } else {
      _health[k] = false;
      _sessionHealth.remove(k);
    }
    _markChecked(k);
    _publish(k, ok);
    notifyListeners();
    onResult?.call(k, ok);
  }

  /// Immediate probe for Sources-panel hover check (skips dwell debounce).
  @override
  Future<bool> checkNow(String key, String url) async {
    final cached = healthFor(key);
    if (cached != null && isFresh(key)) return cached;
    if (_disposed) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    cancel(key);
    try {
      final ok = await PortalAliveChecker.checkOne(trimmed);
      if (_disposed) return ok;
      remember(key, ok);
      return ok;
    } catch (_) {
      if (_disposed) return false;
      remember(key, false);
      return false;
    }
  }

  void schedule(String key, String url, {bool onlyThis = false}) {
    if (_disposed) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (_inFlight.contains(key)) return;
    // Keep last border/dot — re-hover must not wait on CDN again.
    if (isFresh(key)) return;

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
      final ok = await PortalAliveChecker.checkOne(url);
      if (_disposed) return;
      final prev = _health[key] ?? _sessionHealth[key];
      if (ok) {
        _health[key] = true;
        _sessionHealth[key] = true;
      } else {
        _health[key] = false;
        _sessionHealth.remove(key);
      }
      _markChecked(key);
      if (prev == ok) return;
      _publish(key, ok);
      notifyListeners();
      onResult?.call(key, ok);
    } catch (_) {
      if (_disposed) return;
      final prev = _health[key] ?? _sessionHealth[key];
      _health[key] = false;
      _sessionHealth.remove(key);
      _markChecked(key);
      if (prev == false) return;
      _publish(key, false);
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
    for (final n in _listenables.values) {
      n.dispose();
    }
    _listenables.clear();
    super.dispose();
  }
}

