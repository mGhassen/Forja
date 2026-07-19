import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../engine.dart';
import '../domain/provider_score_scope.dart';

/// Per-title provider reliability for the player Source panel.
///
/// Backed by the Rust resolver-engine health store when the engine is ready.
abstract final class ProviderScoreMemory {
  static const serverFailDelta = -2;
  static const serverUpDelta = 2;
  static const streamUpDelta = 2;
  static const streamFailDelta = -2;
  static const allStreamsDownDelta = -2;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool _useLocalOnly = false;
  static bool _loaded = false;
  static Future<void>? _loadFuture;

  /// Local fallback for unit tests without a loaded Rust dylib.
  static final Map<String, int> _server = {};
  static final Map<String, int> _stream = {};
  static final Map<String, int> _lastDelta = {};
  /// Running provider Σ (count up/down, floor 0) — mirrors Rust `tot`.
  static final Map<String, int> _providerTotals = {};

  static Future<void> ensureLoaded() async {
    if (_loaded) return Future.value();
    if (!_useLocalOnly && RustLib.isInitialized) {
      _loaded = true;
      revision.value++;
      return;
    }
    return _loadFuture ??= _loadLocal();
  }

  static Future<void> _loadLocal() async {
    _loaded = true;
    revision.value++;
  }

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

  static int scoreFor(ProviderScoreScope scope, String providerId) {
    final key = _memoryKey(scope, providerId);
    if (_rustReady) {
      return _queryRust(key).score;
    }
    return _totalFor(key);
  }

  /// Running provider Σ across titles (count up/down, never below 0).
  static int globalScoreFor(String providerId) {
    final norm = normalizeProviderId(providerId);
    if (norm.isEmpty) return 0;
    if (_rustReady) {
      try {
        final raw = RustLib.instance.providerHealthJson(
          jsonEncode({'action': 'queryGlobal', 'providerId': norm}),
        );
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return (decoded['score'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        debugPrint('[ProviderScoreMemory] rust global query failed: $e');
      }
      return 0;
    }
    return _providerTotals[norm] ?? 0;
  }

  /// Provider id → running Σ.
  static Map<String, int> allGlobalScores() {
    if (_rustReady) {
      try {
        final raw = RustLib.instance.providerHealthJson(
          jsonEncode({'action': 'queryGlobalAll'}),
        );
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final totals = decoded['totals'];
          if (totals is Map) {
            return {
              for (final e in totals.entries)
                e.key.toString(): (e.value as num?)?.toInt() ?? 0,
            };
          }
        }
      } catch (e) {
        debugPrint('[ProviderScoreMemory] rust global all failed: $e');
      }
      return const {};
    }
    return {
      for (final e in _providerTotals.entries)
        if (e.value > 0) e.key: e.value,
    };
  }

  static void _applyProviderDelta(String memoryKey, int delta) {
    if (delta == 0) return;
    final provider = _providerFromMemoryKey(memoryKey);
    if (provider == null || provider.isEmpty) return;
    final next = ((_providerTotals[provider] ?? 0) + delta).clamp(0, 1 << 30);
    if (next == 0) {
      _providerTotals.remove(provider);
    } else {
      _providerTotals[provider] = next;
    }
  }

  static String? _providerFromMemoryKey(String key) {
    final parts = key.split(':');
    if (parts.isEmpty) return null;
    switch (parts.first) {
      case 'movie':
        if (parts.length < 3) return null;
        return parts.sublist(2).join(':');
      case 'tv':
      case 'anime':
        if (parts.length < 4) return null;
        return parts.sublist(3).join(':');
      default:
        if (parts.length < 3) return null;
        return parts.sublist(2).join(':');
    }
  }

  static int? lastDeltaFor(ProviderScoreScope scope, String providerId) {
    final key = _memoryKey(scope, providerId);
    if (_rustReady) {
      return _queryRust(key).lastDelta;
    }
    return _lastDelta[key];
  }

  static int? serverVerdictFor(ProviderScoreScope scope, String providerId) {
    final key = _memoryKey(scope, providerId);
    if (_rustReady) {
      return _queryRust(key).serverVerdict;
    }
    return _server[key];
  }

  static int? streamVerdictFor(ProviderScoreScope scope, String providerId) {
    final key = _memoryKey(scope, providerId);
    if (_rustReady) {
      return _queryRust(key).streamVerdict;
    }
    return _stream[key];
  }

  static Future<void> recordServerFailure(
    ProviderScoreScope? scope,
    String providerId,
  ) => _setVerdict(scope, providerId, server: serverFailDelta);

  static Future<void> recordServerUp(
    ProviderScoreScope? scope,
    String providerId,
  ) => _setVerdict(scope, providerId, server: serverUpDelta);

  static Future<void> recordStreamUp(
    ProviderScoreScope? scope,
    String providerId,
  ) => _setVerdict(scope, providerId, stream: streamUpDelta, streamWins: true);

  static Future<void> recordStreamFail(
    ProviderScoreScope? scope,
    String providerId,
  ) => _setVerdict(scope, providerId, stream: streamFailDelta);

  @Deprecated('Use recordStreamUp')
  static Future<void> recordStreamCheckUp(
    ProviderScoreScope? scope,
    String providerId,
  ) => recordStreamUp(scope, providerId);

  @Deprecated('Use recordStreamFail')
  static Future<void> recordStreamCheckFail(
    ProviderScoreScope? scope,
    String providerId,
  ) => recordStreamFail(scope, providerId);

  @Deprecated('Use recordStreamUp')
  static Future<void> recordStreamPlayUp(
    ProviderScoreScope? scope,
    String providerId,
  ) => recordStreamUp(scope, providerId);

  @Deprecated('Use recordStreamFail')
  static Future<void> recordStreamPlayFail(
    ProviderScoreScope? scope,
    String providerId,
  ) => recordStreamFail(scope, providerId);

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

  /// Wipe all provider reliability scores (Settings Cache & data).
  static Future<void> clearAll() async {
    await ensureLoaded();
    if (_rustReady) {
      try {
        RustLib.instance.providerHealthJson(jsonEncode({'action': 'clearAll'}));
      } catch (e) {
        debugPrint('[ProviderScoreMemory] rust clearAll failed: $e');
      }
    }
    _server.clear();
    _stream.clear();
    _lastDelta.clear();
    _providerTotals.clear();
    revision.value++;
  }

  @visibleForTesting
  static void resetForTest() {
    _useLocalOnly = true;
    _server.clear();
    _stream.clear();
    _lastDelta.clear();
    _providerTotals.clear();
    _loaded = true;
    _loadFuture = null;
    revision.value++;
  }

  static bool get _rustReady => !_useLocalOnly && RustLib.isInitialized;

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

    if (_rustReady) {
      final action = switch ((server, stream)) {
        (serverUpDelta, _) => 'recordServerUp',
        (serverFailDelta, _) => 'recordServerFailure',
        (_, streamUpDelta) => 'recordStreamUp',
        (_, streamFailDelta) => 'recordStreamFail',
        _ => null,
      };
      if (action != null) {
        _rustAction(action, key, streamWins: streamWins);
        revision.value++;
      }
      return;
    }

    final before = _totalFor(key);
    var changed = false;

    if (server != null && _server[key] != server) {
      _server[key] = server;
      changed = true;
    }
    if (stream != null) {
      final current = _stream[key];
      final blockedByWin =
          !streamWins && stream < 0 && current == streamUpDelta;
      if (!blockedByWin && current != stream) {
        _stream[key] = stream;
        changed = true;
      }
    }

    if (!changed) return;

    final after = _totalFor(key);
    final delta = after - before;
    _lastDelta[key] = delta != 0
        ? delta
        : (stream ?? server ?? _lastDelta[key] ?? 0);
    _applyProviderDelta(key, delta);
    revision.value++;
  }

  static void _rustAction(
    String action,
    String memoryKey, {
    bool streamWins = false,
  }) {
    try {
      RustLib.instance.providerHealthJson(
        jsonEncode({
          'action': action,
          'memoryKey': memoryKey,
          if (streamWins) 'streamWins': true,
        }),
      );
    } catch (e) {
      debugPrint('[ProviderScoreMemory] rust action failed: $e');
    }
  }

  static _HealthQuery _queryRust(String memoryKey) {
    try {
      final raw = RustLib.instance.providerHealthJson(
        jsonEncode({'action': 'query', 'memoryKey': memoryKey}),
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _HealthQuery.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[ProviderScoreMemory] rust query failed: $e');
    }
    return const _HealthQuery(score: 0);
  }

  static int _totalFor(String key) =>
      (_server[key] ?? 0) + (_stream[key] ?? 0);
}

class _HealthQuery {
  const _HealthQuery({
    required this.score,
    this.serverVerdict,
    this.streamVerdict,
    this.lastDelta,
  });

  factory _HealthQuery.fromJson(Map<String, dynamic> json) => _HealthQuery(
    score: (json['score'] as num?)?.toInt() ?? 0,
    serverVerdict: (json['serverVerdict'] as num?)?.toInt(),
    streamVerdict: (json['streamVerdict'] as num?)?.toInt(),
    lastDelta: (json['lastDelta'] as num?)?.toInt(),
  );

  final int score;
  final int? serverVerdict;
  final int? streamVerdict;
  final int? lastDelta;
}
