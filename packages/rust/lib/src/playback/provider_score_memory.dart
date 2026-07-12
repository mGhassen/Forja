import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../kv.dart';
import 'source_order_engine.dart';

/// Runtime reliability penalties applied on top of configured domain scores.
///
/// When a server load or stream probe fails in the player Source panel, the
/// penalty rises so the next panel open (and score badge) reflects it.
/// Successes slowly recover. Caps keep effective scores in 1‥base.
abstract final class ProviderScoreMemory {
  static const _storageKey = 'provider_score_penalties_v1';
  static const serverFailPenalty = 20;
  static const streamFailPenalty = 8;
  static const successRecovery = 5;
  static const maxPenalty = 90;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, int> _penalties = {};
  static bool _loaded = false;
  static Future<void>? _loadFuture;

  static Map<String, int> get penalties => Map.unmodifiable(_penalties);

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final raw = await kvGetString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            final v = (e.value as num?)?.toInt() ?? 0;
            if (v > 0) _penalties[e.key.toString()] = v.clamp(1, maxPenalty);
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

  static Future<void> _persist() async {
    try {
      await kvSetString(_storageKey, jsonEncode(_penalties));
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

  static int effectiveScore(int domainScore, String providerId) {
    if (domainScore <= 0) return 0;
    return (domainScore - penaltyFor(providerId)).clamp(1, domainScore);
  }

  /// Apply persisted penalties to Source Engine rows for UI + sort.
  static Map<String, ProviderOrderRow> applyToRows(
    Map<String, ProviderOrderRow> rows,
  ) {
    if (rows.isEmpty || _penalties.isEmpty) return rows;
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

  static Future<void> recordServerFailure(String providerId) =>
      _adjust(providerId, serverFailPenalty);

  static Future<void> recordStreamFailure(String providerId) =>
      _adjust(providerId, streamFailPenalty);

  static Future<void> recordSuccess(String providerId) =>
      _adjust(providerId, -successRecovery);

  static Future<void> _adjust(String providerId, int delta) async {
    final id = _normalizeId(providerId);
    if (id.isEmpty) return;
    await ensureLoaded();
    final prev = _penalties[id] ?? 0;
    final next = (prev + delta).clamp(0, maxPenalty);
    if (next == prev) return;
    if (next == 0) {
      _penalties.remove(id);
    } else {
      _penalties[id] = next;
    }
    revision.value++;
    await _persist();
  }
}
