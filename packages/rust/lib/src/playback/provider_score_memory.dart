import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../kv.dart';
import 'provider_score_scope.dart';

/// Per-title provider reliability for the player Source panel.
///
/// Scores are stored per film, TV episode, or anime episode — not globally.
/// Settings base is **0**. Server and stream outcomes **add** separately
/// (server ±2, stream ±2; server+stream ok → +2+2=+4). All streams down −2.
/// Asian drama is not tracked. Score never goes below 0; no cap.
abstract final class ProviderScoreMemory {
  static const _legacyV3Key = 'provider_score_reliability_v3';
  static const _legacyV2Key = 'provider_score_reliability_v2';
  static const _legacyV1Key = 'provider_score_penalties_v1';
  static const _storageKey = 'provider_score_reliability_v4';

  static const serverFailDelta = -2;
  static const serverUpDelta = 2;
  static const streamUpDelta = 2;
  static const streamFailDelta = -2;
  static const allStreamsDownDelta = -2;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, int> _scores = {};
  static final Map<String, int> _lastDelta = {};
  /// Session-only — scoped server had a working stream since last all-down wipe.
  static final Map<String, bool> _serverWasWorking = {};

  static bool _loaded = false;
  static Future<void>? _loadFuture;

  static Map<String, int> get scores => Map.unmodifiable(_scores);

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      var raw = await kvGetString(_storageKey);
      if (raw == null || raw.isEmpty) {
        raw = await kvGetString(_legacyV3Key);
      }
      if (raw == null || raw.isEmpty) {
        raw = await kvGetString(_legacyV2Key);
      }
      if (raw == null || raw.isEmpty) {
        raw = await kvGetString(_legacyV1Key);
      }
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded.containsKey('s')) {
          _readScoreMap(decoded['s']);
          _readDeltaMap(decoded['d']);
        }
      }
    } catch (e) {
      debugPrint('[ProviderScoreMemory] load failed: $e');
    } finally {
      _loaded = true;
      revision.value++;
    }
  }

  static void _readScoreMap(dynamic raw) {
    if (raw is! Map) return;
    for (final e in raw.entries) {
      final v = (e.value as num?)?.toInt() ?? 0;
      if (v >= 0) _scores[e.key.toString()] = v;
    }
  }

  static void _readDeltaMap(dynamic raw) {
    if (raw is! Map) return;
    for (final e in raw.entries) {
      final v = (e.value as num?)?.toInt();
      if (v == null || v == 0) continue;
      _lastDelta[e.key.toString()] = v;
    }
  }

  static Future<void> _persist() async {
    try {
      await kvSetString(
        _storageKey,
        jsonEncode({'s': _scores, 'd': _lastDelta}),
      );
    } catch (e) {
      debugPrint('[ProviderScoreMemory] persist failed: $e');
    }
  }

  /// Anime panel keys are `sourceKey:sub|dub` — one score per engine id.
  static String normalizeProviderId(String providerId) {
    final id = providerId.trim();
    if (id.isEmpty) return id;
    final lower = id.toLowerCase();
    if (lower.endsWith(':sub') || lower.endsWith(':dub')) {
      return id.substring(0, id.lastIndexOf(':'));
    }
    return id;
  }

  static String _memoryKey(ProviderScoreScope scope, String providerId) =>
      scope.memoryKey(normalizeProviderId(providerId));

  static int scoreFor(ProviderScoreScope scope, String providerId) =>
      _scores[_memoryKey(scope, providerId)] ?? 0;

  static int? lastDeltaFor(ProviderScoreScope scope, String providerId) {
    final key = _memoryKey(scope, providerId);
    if (!_lastDelta.containsKey(key)) return null;
    return _lastDelta[key];
  }

  static Future<void> recordServerFailure(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    await _adjust(scope, providerId, serverFailDelta);
  }

  static Future<void> recordServerUp(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    if (scope == null) return;
    final key = _memoryKey(scope, providerId);
    _serverWasWorking[key] = true;
    await _adjust(scope, providerId, serverUpDelta);
  }

  static Future<void> recordStreamUp(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    if (scope == null) return;
    final key = _memoryKey(scope, providerId);
    _serverWasWorking[key] = true;
    await _adjust(scope, providerId, streamUpDelta);
  }

  static Future<void> recordStreamFail(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    await _adjust(scope, providerId, streamFailDelta);
  }

  @Deprecated('Use recordStreamUp')
  static Future<void> recordStreamCheckUp(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    await recordStreamUp(scope, providerId);
  }

  @Deprecated('Use recordStreamFail')
  static Future<void> recordStreamCheckFail(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    await recordStreamFail(scope, providerId);
  }

  @Deprecated('Use recordStreamUp')
  static Future<void> recordStreamPlayUp(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    await recordStreamUp(scope, providerId);
  }

  @Deprecated('Use recordStreamFail')
  static Future<void> recordStreamPlayFail(
    ProviderScoreScope? scope,
    String providerId,
  ) async {
    await recordStreamFail(scope, providerId);
  }

  static Future<bool> recordAllStreamsDownIfNeeded({
    required ProviderScoreScope? scope,
    required String providerId,
    required List<String> streamUrls,
    required bool Function(String url) isStreamFailed,
  }) async {
    if (scope == null) return false;
    await ensureLoaded();
    final key = _memoryKey(scope, providerId);
    if (!(_serverWasWorking[key] ?? false)) return false;
    if (streamUrls.isEmpty) return false;

    for (final url in streamUrls) {
      if (!isStreamFailed(url)) return false;
    }

    _serverWasWorking[key] = false;
    await _adjust(scope, providerId, allStreamsDownDelta);
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    _scores.clear();
    _lastDelta.clear();
    _serverWasWorking.clear();
    _loaded = true;
    _loadFuture = null;
  }

  static Future<bool> _adjust(
    ProviderScoreScope? scope,
    String providerId,
    int delta,
  ) async {
    if (scope == null || delta == 0) return false;
    await ensureLoaded();
    final key = _memoryKey(scope, providerId);
    if (key.isEmpty) return false;

    final prev = _scores[key] ?? 0;
    final next = (prev + delta).clamp(0, 1 << 30);
    if (next == prev) {
      _lastDelta[key] = delta;
      revision.value++;
      await _persist();
      return true;
    }

    _scores[key] = next;
    _lastDelta[key] = delta;
    revision.value++;
    await _persist();
    return true;
  }
}
