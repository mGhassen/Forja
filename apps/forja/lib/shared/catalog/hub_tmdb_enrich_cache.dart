import 'package:flutter/foundation.dart';

/// Process-lifetime cache for hub / details TMDB enrich results.
///
/// Riverpod `autoDispose` dumps providers when you leave details — this keeps
/// the expensive match + rich payload so reopen is instant.
class HubTmdbEnrichCache {
  HubTmdbEnrichCache._();

  static const _ttl = Duration(minutes: 30);
  static const _max = 256;

  static final Map<String, _Entry> _entries = {};

  static bool contains(String key) {
    final e = _entries[key];
    if (e == null) return false;
    if (DateTime.now().difference(e.at) > _ttl) {
      _entries.remove(key);
      return false;
    }
    return true;
  }

  static T? get<T>(String key) {
    if (!contains(key)) return null;
    return _entries[key]!.value as T?;
  }

  static void put(String key, Object? value) {
    if (_entries.length >= _max) {
      final now = DateTime.now();
      _entries.removeWhere((_, e) => now.difference(e.at) > _ttl);
      if (_entries.length >= _max) _entries.clear();
    }
    _entries[key] = _Entry(value, DateTime.now());
  }

  @visibleForTesting
  static void wipeAll() => _entries.clear();

  @visibleForTesting
  static int get length => _entries.length;
}

class _Entry {
  const _Entry(this.value, this.at);
  final Object? value;
  final DateTime at;
}
