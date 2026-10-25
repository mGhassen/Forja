import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pack + identity Continue Watching — keyed by [pluginId] and account/profile/guest.
///
/// Opaque [MetaItem] rows only. No TMDB / Home product shaping here.
class WatchHistory {
  WatchHistory._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static bool _listening = false;

  static void _ensureScopeListener() {
    if (_listening) return;
    _listening = true;
    LocalDataScope.addListener(() async {
      revision.value++;
    });
  }

  static String _storageKey(String pluginId) {
    _ensureScopeListener();
    return LocalDataScope.storageKey('catalog_cw_$pluginId');
  }

  static Future<List<Map<String, dynamic>>> getAll(String pluginId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_storageKey(pluginId)) ?? const [];
    final out = <Map<String, dynamic>>[];
    for (final line in raw) {
      try {
        out.add(jsonDecode(line) as Map<String, dynamic>);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> record({
    required String pluginId,
    required MetaItem meta,
    required int episodeNumber,
    int? season,
    String? episodeVideoId,
    Map<String, dynamic> extras = const {},
    Duration? position,
    Duration? duration,
    String? sourceId,
    String? streamUrl,

    /// After finishing an ep — keep the show on CW as the next episode.
    bool upNext = false,
  }) async {
    final p = await SharedPreferences.getInstance();
    final list = <String>[
      ...(p.getStringList(_storageKey(pluginId)) ?? const []),
    ];
    String? prevSourceId;
    String? prevStreamUrl;
    int? prevPositionMs;
    int? prevDurationMs;
    var priorEligible = false;
    // Heartbeat after ≥85% must not clobber an up-next seed for a later ep.
    if (!upNext &&
        position != null &&
        duration != null &&
        isWatchFinished(position.inMilliseconds, duration.inMilliseconds)) {
      for (final line in list) {
        try {
          final m = jsonDecode(line) as Map<String, dynamic>;
          if (m['metaId'] != meta.id) continue;
          if (m['upNext'] != true) break;
          final seeded = (m['episodeNumber'] as num?)?.toInt() ?? 0;
          if (seeded > episodeNumber) return;
          break;
        } catch (_) {}
      }
    }
    list.removeWhere((line) {
      try {
        final m = jsonDecode(line) as Map<String, dynamic>;
        if (m['metaId'] == meta.id) {
          prevSourceId = m['sourceId']?.toString();
          prevStreamUrl = m['streamUrl']?.toString();
          prevPositionMs = (m['positionMs'] as num?)?.toInt();
          prevDurationMs = (m['durationMs'] as num?)?.toInt();
          priorEligible = isContinueWatchingEligible(
            prevPositionMs ?? 0,
            prevDurationMs ?? 0,
            upNext: isUpNextContinueFlag(m['upNext']),
            showStarted: isShowStartedContinueFlag(m['showStarted']),
          );
          return true;
        }
        return false;
      } catch (_) {
        return true;
      }
    });
    // Up-next clears the finished ep's stream pin — Play re-resolves.
    final sid = upNext ? null : (sourceId ?? prevSourceId)?.trim();
    final url = upNext ? null : (streamUrl ?? prevStreamUrl)?.trim();
    // Null position/duration = seed / metadata-only write — keep prior resume.
    // Up-next always starts at 0 (do not inherit finished progress).
    final posMs = upNext
        ? 0
        : (position?.inMilliseconds ?? prevPositionMs ?? 0);
    final durMs = upNext
        ? 0
        : (duration?.inMilliseconds ?? prevDurationMs ?? 0);
    final finished = durMs > 0 && isWatchFinished(posMs, durMs);
    final inProgress = isInProgressResume(posMs, durMs);
    // Show-scoped: once on CW, later eps stay without waiting for 2%.
    final showStarted = !finished && (upNext || priorEligible || inProgress);
    list.insert(
      0,
      jsonEncode({
        'metaId': meta.id,
        'pluginId': pluginId,
        'title': meta.name,
        'cover': meta.background.isNotEmpty ? meta.background : meta.poster,
        'poster': meta.poster,
        'episodeNumber': episodeNumber,
        'season': ?season,
        if (episodeVideoId != null && episodeVideoId.isNotEmpty)
          'episodeVideoId': episodeVideoId,
        if (extras.isNotEmpty) 'extras': extras,
        if (sid != null && sid.isNotEmpty) 'sourceId': sid,
        if (url != null && url.isNotEmpty) 'streamUrl': url,
        'positionMs': posMs,
        'durationMs': durMs,
        if (upNext) 'upNext': true,
        if (showStarted) 'showStarted': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'meta': meta.toJson(),
      }),
    );
    if (list.length > 50) list.removeRange(50, list.length);
    await p.setStringList(_storageKey(pluginId), list);
    revision.value++;
  }

  static Future<void> remove(String pluginId, String metaId) async {
    final p = await SharedPreferences.getInstance();
    final list = <String>[
      ...(p.getStringList(_storageKey(pluginId)) ?? const []),
    ];
    list.removeWhere((line) {
      try {
        return (jsonDecode(line) as Map<String, dynamic>)['metaId'] == metaId;
      } catch (_) {
        return true;
      }
    });
    await p.setStringList(_storageKey(pluginId), list);
    revision.value++;
  }

  static Future<void> clear(String pluginId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_storageKey(pluginId));
    revision.value++;
  }

  static MetaItem? metaFromEntry(Map<String, dynamic> entry) {
    final raw = entry['meta'];
    if (raw is Map) {
      return MetaItem.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}
