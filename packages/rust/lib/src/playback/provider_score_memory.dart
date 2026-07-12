import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../kv.dart';
import 'provider_score_scope.dart';

/// Per-title provider reliability for the player Source panel.
///
/// Scored per film, TV episode, or anime episode — never global, never Asian
/// drama. Each provider carries two **verdicts** that are **netted**, not
/// accumulated:
///
/// - **server**: `+2` when it resolves/extracts streams, `-2` when it fails to.
/// - **stream**: `+2` when at least one of its streams plays/probes OK, `-2`
///   when every extracted stream is dead.
///
/// Total = `server + stream`, floored at 0 (no cap). So an up server whose
/// streams are all dead nets `+2 - 2 = 0`; up server with a working stream nets
/// `+4`; a server that never resolved nets `-2 → 0`.
abstract final class ProviderScoreMemory {
  static const _legacyV4Key = 'provider_score_reliability_v4';
  static const _legacyV3Key = 'provider_score_reliability_v3';
  static const _legacyV2Key = 'provider_score_reliability_v2';
  static const _legacyV1Key = 'provider_score_penalties_v1';
  static const _storageKey = 'provider_score_reliability_v5';

  static const serverFailDelta = -2;
  static const serverUpDelta = 2;
  static const streamUpDelta = 2;
  static const streamFailDelta = -2;
  static const allStreamsDownDelta = -2;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Last server verdict per scoped key: `+2`, `-2`, or absent (unknown).
  static final Map<String, int> _server = {};

  /// Last stream verdict per scoped key: `+2`, `-2`, or absent (unknown).
  static final Map<String, int> _stream = {};

  /// Last change applied to a key's total — drives the `+/−` badge prefix.
  static final Map<String, int> _lastDelta = {};

  static bool _loaded = false;
  static Future<void>? _loadFuture;

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
          _readVerdictMap(decoded['srv'], _server);
          _readVerdictMap(decoded['str'], _stream);
          _readDeltaMap(decoded['d']);
        }
      } else {
        await _migrateLegacyTotals();
      }
    } catch (e) {
      debugPrint('[ProviderScoreMemory] load failed: $e');
    } finally {
      _loaded = true;
      revision.value++;
    }
  }

  /// Old schemas stored a single positive total. Fold it into the server
  /// verdict so previously-good providers do not reset to 0 on upgrade.
  static Future<void> _migrateLegacyTotals() async {
    for (final key in [_legacyV4Key, _legacyV3Key, _legacyV2Key, _legacyV1Key]) {
      final raw = await kvGetString(key);
      if (raw == null || raw.isEmpty) continue;
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['s'] is Map) {
        final scores = decoded['s'] as Map;
        for (final e in scores.entries) {
          final total = (e.value as num?)?.toInt() ?? 0;
          if (total > 0) _server[e.key.toString()] = serverUpDelta;
        }
        return;
      }
    }
  }

  static void _readVerdictMap(dynamic raw, Map<String, int> into) {
    if (raw is! Map) return;
    for (final e in raw.entries) {
      final v = (e.value as num?)?.toInt();
      if (v == null || v == 0) continue;
      into[e.key.toString()] = v.clamp(-2, 2);
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
        jsonEncode({'srv': _server, 'str': _stream, 'd': _lastDelta}),
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

  static int _rawTotalFor(String key) =>
      (_server[key] ?? 0) + (_stream[key] ?? 0);

  static int _totalFor(String key) => _rawTotalFor(key).clamp(0, 1 << 30);

  static int scoreFor(ProviderScoreScope scope, String providerId) =>
      _totalFor(_memoryKey(scope, providerId));

  static int? lastDeltaFor(ProviderScoreScope scope, String providerId) {
    final key = _memoryKey(scope, providerId);
    return _lastDelta[key];
  }

  /// Current server verdict for the badge (`+2` / `-2`), if any.
  static int? serverVerdictFor(ProviderScoreScope scope, String providerId) =>
      _server[_memoryKey(scope, providerId)];

  /// Current stream verdict for the badge (`+2` / `-2`), if any.
  static int? streamVerdictFor(ProviderScoreScope scope, String providerId) =>
      _stream[_memoryKey(scope, providerId)];

  static Future<void> recordServerFailure(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      _setVerdict(scope, providerId, server: serverFailDelta);

  static Future<void> recordServerUp(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      _setVerdict(scope, providerId, server: serverUpDelta);

  /// A working stream — wins over any prior dead-stream verdict for this title.
  static Future<void> recordStreamUp(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      _setVerdict(scope, providerId, stream: streamUpDelta, streamWins: true);

  /// A dead stream — only lowers the verdict if no stream has proven working.
  static Future<void> recordStreamFail(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      _setVerdict(scope, providerId, stream: streamFailDelta);

  @Deprecated('Use recordStreamUp')
  static Future<void> recordStreamCheckUp(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      recordStreamUp(scope, providerId);

  @Deprecated('Use recordStreamFail')
  static Future<void> recordStreamCheckFail(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      recordStreamFail(scope, providerId);

  @Deprecated('Use recordStreamUp')
  static Future<void> recordStreamPlayUp(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      recordStreamUp(scope, providerId);

  @Deprecated('Use recordStreamFail')
  static Future<void> recordStreamPlayFail(
    ProviderScoreScope? scope,
    String providerId,
  ) =>
      recordStreamFail(scope, providerId);

  /// Marks the stream verdict dead when every extracted stream failed. Kept for
  /// call-site compatibility; equivalent to [recordStreamFail] under the netted
  /// model.
  static Future<bool> recordAllStreamsDownIfNeeded({
    required ProviderScoreScope? scope,
    required String providerId,
    required List<String> streamUrls,
    required bool Function(String url) isStreamFailed,
  }) async {
    if (scope == null || streamUrls.isEmpty) return false;
    for (final url in streamUrls) {
      if (!isStreamFailed(url)) return false;
    }
    await recordStreamFail(scope, providerId);
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    _server.clear();
    _stream.clear();
    _lastDelta.clear();
    _loaded = true;
    _loadFuture = null;
  }

  static Future<void> _setVerdict(
    ProviderScoreScope? scope,
    String providerId, {
    int? server,
    int? stream,
    bool streamWins = false,
  }) async {
    if (scope == null) return;
    await ensureLoaded();
    final key = _memoryKey(scope, providerId);
    if (key.isEmpty) return;

    final before = _totalFor(key);
    var changed = false;

    if (server != null && _server[key] != server) {
      _server[key] = server;
      changed = true;
    }
    if (stream != null) {
      final current = _stream[key];
      // A proven-working stream (+2) is sticky: a later dead-stream report for
      // the same title must not erase it. An explicit stream-up always wins.
      final blockedByWin = !streamWins &&
          stream < 0 &&
          current == streamUpDelta;
      if (!blockedByWin && current != stream) {
        _stream[key] = stream;
        changed = true;
      }
    }

    if (!changed) return;

    final after = _totalFor(key);
    final delta = after - before;
    // Record the observed verdict sign even when the floored total did not move
    // (e.g. -2 while already at 0) so the badge still shows the last change.
    _lastDelta[key] = delta != 0
        ? delta
        : (stream ?? server ?? _lastDelta[key] ?? 0);
    revision.value++;
    await _persist();
  }
}
