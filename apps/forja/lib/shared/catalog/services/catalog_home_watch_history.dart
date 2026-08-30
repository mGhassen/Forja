import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/playback/hub_engine_watch_history.dart';
import 'package:rust/rust.dart';

/// Home hub (`tmdb` pack) still plays through TMDB details → [WatchHistoryService].
const String catalogHomeWatchPluginId = 'tmdb';

bool catalogHomeUsesLegacyWatchHistory(String pluginId) =>
    pluginId == catalogHomeWatchPluginId;

String catalogPosterUrlFromHistoryPath(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http')) {
    return p.replaceAll('media.themoviedb.org/t/p', 'image.tmdb.org/t/p');
  }
  return 'https://image.tmdb.org/t/p/w500$p';
}

CatalogMetaItem? catalogMetaFromLegacyWatchEntry(Map<String, dynamic> item) {
  if (!isHomeTabWatchHistoryEntry(item)) return null;
  final tmdbId = watchHistoryInt(item['tmdbId'], -1);
  if (tmdbId < 0) return null;
  final season = item['season'] as int?;
  final rawType =
      item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
  final type = rawType == 'tv' || rawType == 'series' ? 'tv' : 'movie';
  final poster = catalogPosterUrlFromHistoryPath(item['posterPath']?.toString());
  final backdrop = catalogPosterUrlFromHistoryPath(
    item['backdropPath']?.toString() ?? item['posterPath']?.toString(),
  );
  return CatalogMetaItem(
    id: 'tmdb:$type:$tmdbId',
    type: type,
    name: (item['title'] as String?)?.trim() ?? '',
    poster: poster,
    background: backdrop.isNotEmpty ? backdrop : poster,
    ids: {'tmdb': tmdbId.toString()},
    open: CatalogOpen(
      surface: 'tmdb',
      id: tmdbId.toString(),
      extras: {'mediaType': type},
    ),
  );
}

Map<String, dynamic>? legacyWatchEntryToCatalogContinueEntry(
  Map<String, dynamic> item,
) {
  final pos = watchHistoryInt(item['position']);
  final dur = watchHistoryInt(item['duration']);
  if (!isInProgressResume(pos, dur)) return null;
  final meta = catalogMetaFromLegacyWatchEntry(item);
  if (meta == null) return null;
  final episode = item['episode'] as int? ?? item['season'] as int? ?? 1;
  return {
    'metaId': meta.id,
    'pluginId': catalogHomeWatchPluginId,
    'title': meta.name,
    'cover': meta.background.isNotEmpty ? meta.background : meta.poster,
    'poster': meta.poster,
    'episodeNumber': episode,
    'positionMs': pos,
    'durationMs': dur,
    'meta': meta.toJson(),
    '_legacyUniqueId': item['uniqueId'],
    '_legacyWatch': item,
  };
}

Future<List<Map<String, dynamic>>> catalogContinueEntries(String pluginId) async {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  void add(Map<String, dynamic> entry) {
    final metaId = entry['metaId']?.toString();
    if (metaId == null || metaId.isEmpty || !seen.add(metaId)) return;
    out.add(entry);
  }

  for (final entry in await CatalogWatchHistory.getAll(pluginId)) {
    final pos = (entry['positionMs'] as num?)?.toInt() ?? 0;
    final dur = (entry['durationMs'] as num?)?.toInt() ?? 0;
    if (!isInProgressResume(pos, dur)) continue;
    add(entry);
  }

  if (catalogHomeUsesLegacyWatchHistory(pluginId)) {
    for (final item in WatchHistoryService().current) {
      final mapped = legacyWatchEntryToCatalogContinueEntry(item);
      if (mapped != null) add(mapped);
    }
  }

  return out.take(10).toList();
}

Future<List<Map<String, dynamic>>> catalogResumeSeedsForPlugin(
  String pluginId,
) async {
  final seeds = <Map<String, dynamic>>[];
  final seen = <String>{};

  void addSeed({required String title, required Map<String, dynamic> meta}) {
    final id = meta['id']?.toString();
    if (id == null || id.isEmpty || !seen.add(id)) return;
    seeds.add({'title': title, 'meta': meta});
  }

  for (final entry in await CatalogWatchHistory.getAll(pluginId)) {
    final meta = entry['meta'];
    if (meta is! Map) continue;
    addSeed(
      title: (entry['title'] ?? meta['name'] ?? '').toString(),
      meta: Map<String, dynamic>.from(meta),
    );
  }

  if (catalogHomeUsesLegacyWatchHistory(pluginId)) {
    for (final item in inProgressPoolByShow(WatchHistoryService().current)) {
      final meta = catalogMetaFromLegacyWatchEntry(item);
      if (meta == null) continue;
      addSeed(title: meta.name, meta: meta.toJson());
    }
  }

  return seeds;
}

/// Subscribes to legacy home history updates (no-op for other packs).
StreamSubscription<List<Map<String, dynamic>>>? listenLegacyHomeWatchHistory(
  VoidCallback onChanged,
) {
  return WatchHistoryService().historyStream.listen((_) => onChanged());
}
