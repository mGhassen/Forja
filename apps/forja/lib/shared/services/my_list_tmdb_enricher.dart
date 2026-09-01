import 'dart:convert';

import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_list_item.dart';
import 'package:rust/rust.dart';

/// TMDB hydrate for My List rows — service layer only (not catalog kit).
class MyListTmdbEnricher {
  MyListTmdbEnricher._();

  static const _batchSize = 5;

  static Future<List<Map<String, dynamic>>> enrichBatch(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;
    final out = List<Map<String, dynamic>>.from(rows);
    final indices = <int>[];
    for (var i = 0; i < out.length; i++) {
      if (_needsEnrich(out[i])) indices.add(i);
    }
    for (var i = 0; i < indices.length; i += _batchSize) {
      final chunk = indices.skip(i).take(_batchSize);
      await Future.wait(chunk.map((idx) => _enrichRow(out, idx)));
    }
    return out;
  }

  static bool _needsEnrich(Map<String, dynamic> row) {
    if (row['catalogOpen'] != null) return false;
    if (row['anilistId'] != null || row['kisskhId'] != null) return false;
    final tmdbId = row['tmdbId'];
    if (tmdbId is! int) return false;
    final poster = row['posterPath']?.toString() ?? '';
    final title = row['title']?.toString() ?? '';
    final vote = row['voteAverage'];
    return poster.isEmpty ||
        title.isEmpty ||
        vote == null ||
        (vote is num && vote == 0);
  }

  static Future<void> _enrichRow(
    List<Map<String, dynamic>> rows,
    int index,
  ) async {
    final row = rows[index];
    final tmdbId = row['tmdbId'] as int?;
    if (tmdbId == null) return;
    final kind = row['_simklType']?.toString();
    final mt = row['mediaType']?.toString() ?? 'movie';
    final mediaType = kind == 'shows' || mt == 'tv' || mt == 'series'
        ? 'tv'
        : 'movie';
    try {
      final raw = await runTmdbGetJson('$mediaType/$tmdbId');
      final data = json.decode(raw);
      if (data is! Map<String, dynamic> || data['error'] != null) return;
      final title = (data['title'] ?? data['name'])?.toString();
      final poster = data['poster_path']?.toString() ?? '';
      final backdrop = data['backdrop_path']?.toString() ?? '';
      final vote = (data['vote_average'] as num?)?.toDouble() ?? 0;
      final date = (data['release_date'] ?? data['first_air_date'])?.toString() ??
          '';
      final next = Map<String, dynamic>.from(row);
      if (title != null && title.isNotEmpty) next['title'] = title;
      if (poster.isNotEmpty) next['posterPath'] = poster;
      if (backdrop.isNotEmpty) next['backdropPath'] = backdrop;
      if (vote > 0) next['voteAverage'] = vote;
      if (date.isNotEmpty) next['releaseDate'] = date;
      if (next['catalogOpen'] == null) {
        next['catalogOpen'] = {
          'surface': 'tmdb',
          'id': '$tmdbId',
          'extract': {
            'resolveType': mediaType,
            'panelCategory': mediaType,
            'ctx': {'tmdbId': tmdbId},
          },
        };
      }
      rows[index] = next;
    } catch (_) {}
  }

  static CatalogMetaItem metaFromRow(Map<String, dynamic> row) {
    return catalogMetaFromLegacyListItem(row);
  }

  static Future<String?> pluginIdForRow(Map<String, dynamic> row) async {
    final stored = row['pluginId']?.toString();
    if (stored != null && stored.isNotEmpty) return stored;
    final meta = catalogMetaFromLegacyListItem(row);
    final open = meta.open;
    if (open == null) return null;
    if (open.surface == 'tmdb') {
      return PluginNavRegistry.pluginIdForEngineType('movie');
    }
    return PluginNavRegistry.resolveHubPluginId(
      pluginId: stored,
      engineType: open.effectiveExtract.panelCategory,
    );
  }
}
