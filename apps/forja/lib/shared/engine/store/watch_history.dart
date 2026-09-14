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
    String? episodeVideoId,
    Map<String, dynamic> extras = const {},
    Duration? position,
    Duration? duration,
  }) async {
    final p = await SharedPreferences.getInstance();
    final list = <String>[
      ...(p.getStringList(_storageKey(pluginId)) ?? const []),
    ];
    list.removeWhere((line) {
      try {
        final m = jsonDecode(line) as Map<String, dynamic>;
        return m['metaId'] == meta.id;
      } catch (_) {
        return true;
      }
    });
    list.insert(
      0,
      jsonEncode({
        'metaId': meta.id,
        'pluginId': pluginId,
        'title': meta.name,
        'cover': meta.background.isNotEmpty ? meta.background : meta.poster,
        'poster': meta.poster,
        'episodeNumber': episodeNumber,
        if (episodeVideoId != null && episodeVideoId.isNotEmpty)
          'episodeVideoId': episodeVideoId,
        if (extras.isNotEmpty) 'extras': extras,
        'positionMs': position?.inMilliseconds ?? 0,
        'durationMs': duration?.inMilliseconds ?? 0,
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

/// Opaque resume rows for pack `because` rails — host does not interpret meta.
Future<List<Map<String, dynamic>>> catalogResumeSeeds(String pluginId) async {
  final entries = await WatchHistory.getAll(pluginId);
  return [
    for (final e in entries)
      {
        'title': e['title'],
        if (e['meta'] is Map) 'meta': e['meta'],
      },
  ];
}
