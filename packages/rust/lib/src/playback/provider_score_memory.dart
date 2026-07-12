import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../kv.dart';
import 'source_order_engine.dart';

/// Runtime reliability adjustments applied on top of configured domain scores.
///
/// Failures add penalty (and trim boost). Successes recover penalty and add
/// boost so the Source panel badge updates while open via [revision].
abstract final class ProviderScoreMemory {
  static const _legacyStorageKey = 'provider_score_penalties_v1';
  static const _storageKey = 'provider_score_reliability_v2';
  static const serverFailPenalty = 20;
  static const streamFailPenalty = 8;
  static const successRecovery = 5;
  static const successBoost = 4;
  static const maxPenalty = 90;
  static const maxBoost = 20;
  static const streamFailBoostLoss = 6;
  static const serverFailBoostLoss = 12;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, int> _penalties = {};
  static final Map<String, int> _boosts = {};
  static bool _loaded = false;
  static Future<void>? _loadFuture;

  static Map<String, int> get penalties => Map.unmodifiable(_penalties);
  static Map<String, int> get boosts => Map.unmodifiable(_boosts);

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      var raw = await kvGetString(_storageKey);
      if (raw == null || raw.isEmpty) {
        raw = await kvGetString(_legacyStorageKey);
      }
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          if (decoded.containsKey('p') || decoded.containsKey('b')) {
            _readIntMap(decoded['p'], _penalties, maxPenalty);
            _readIntMap(decoded['b'], _boosts, maxBoost);
          } else {
            _readIntMap(decoded, _penalties, maxPenalty);
          }
        }
      }
    } catch (e) {
      debugPrint('[ProviderScoreMemory] load failed: $e');
    } finally {
      _loaded = true;
      revision.value++;
    }
  }

  static void _readIntMap(
    dynamic raw,
    Map<String, int> target,
    int maxValue,
  ) {
    if (raw is! Map) return;
    for (final e in raw.entries) {
      final v = (e.value as num?)?.toInt() ?? 0;
      if (v > 0) target[e.key.toString()] = v.clamp(1, maxValue);
    }
  }

  static Future<void> _persist() async {
    try {
      await kvSetString(
        _storageKey,
        jsonEncode({'p': _penalties, 'b': _boosts}),
      );
    } catch (e) {
      debugPrint('[ProviderScoreMemory] persist failed: $e');
    }
  }

  /// Anime panel keys are `sourceKey:sub|dub` — score by engine sourceKey.
  static String _normalizeId(String providerId) {
    final id = providerId.trim();
    if (id.isEmpty) return id;
    final lower = id.toLowerCase();
    if (lower.endsWith(':sub') || lower.endsWith(':dub')) {
      return id.substring(0, id.lastIndexOf(':'));
    }
    return id;
  }

  static int penaltyFor(String providerId) =>
      _penalties[_normalizeId(providerId)] ?? 0;

  static int boostFor(String providerId) =>
      _boosts[_normalizeId(providerId)] ?? 0;

  static int effectiveScore(int domainScore, String providerId) {
    if (domainScore <= 0) return 0;
    final id = _normalizeId(providerId);
    final penalty = _penalties[id] ?? 0;
    final boost = _boosts[id] ?? 0;
    return (domainScore - penalty + boost).clamp(1, domainScore);
  }

  /// Apply persisted reliability memory to Source Engine rows for UI + sort.
  static Map<String, ProviderOrderRow> applyToRows(
    Map<String, ProviderOrderRow> rows,
  ) {
    if (rows.isEmpty) return rows;
    if (_penalties.isEmpty && _boosts.isEmpty) return rows;
    return {
      for (final e in rows.entries)
        e.key: ProviderOrderRow(
          id: e.value.id,
          settingsRank: e.value.settingsRank,
          domainScore: effectiveScore(e.value.domainScore, e.key),
          effectiveRank: e.value.effectiveRank,
          maxDisplacement: e.value.maxDisplacement,
          supported: e.value.supported,
        ),
    };
  }

  static Future<void> recordServerFailure(String providerId) async {
    await ensureLoaded();
    final changed = _adjustPenalty(providerId, serverFailPenalty) |
        _adjustBoost(providerId, -serverFailBoostLoss);
    if (!changed) return;
    revision.value++;
    await _persist();
  }

  static Future<void> recordStreamFailure(String providerId) async {
    await ensureLoaded();
    final changed = _adjustPenalty(providerId, streamFailPenalty) |
        _adjustBoost(providerId, -streamFailBoostLoss);
    if (!changed) return;
    revision.value++;
    await _persist();
  }

  static Future<void> recordSuccess(String providerId) async {
    await ensureLoaded();
    final changed = _adjustPenalty(providerId, -successRecovery) |
        _adjustBoost(providerId, successBoost);
    if (!changed) return;
    revision.value++;
    await _persist();
  }

  static bool _adjustPenalty(String providerId, int delta) {
    final id = _normalizeId(providerId);
    if (id.isEmpty) return false;
    final prev = _penalties[id] ?? 0;
    final next = (prev + delta).clamp(0, maxPenalty);
    if (next == prev) return false;
    if (next == 0) {
      _penalties.remove(id);
    } else {
      _penalties[id] = next;
    }
    return true;
  }

  static bool _adjustBoost(String providerId, int delta) {
    final id = _normalizeId(providerId);
    if (id.isEmpty) return false;
    final prev = _boosts[id] ?? 0;
    final next = (prev + delta).clamp(0, maxBoost);
    if (next == prev) return false;
    if (next == 0) {
      _boosts.remove(id);
    } else {
      _boosts[id] = next;
    }
    return true;
  }
}
