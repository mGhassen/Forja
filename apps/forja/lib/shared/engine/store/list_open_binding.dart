import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/store/list_open_prefs.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/settings/pack_hub_select_options.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

/// Installed details hub the user can open a My List row into.
@immutable
class ListOpenCandidate {
  const ListOpenCandidate({
    required this.pluginId,
    required this.label,
    required this.types,
    required this.compatible,
    this.hasSearch = false,
  });

  final String pluginId;
  final String label;
  final List<String> types;

  /// Row already has identity keys this hub can use without search.
  final bool compatible;
  final bool hasSearch;

  bool get needsSearch => !compatible;
}

/// Engine-type tokens implied by a list row (opaque open / mediaType only).
@visibleForTesting
Set<String> listOpenIdentityTokens(Map<String, dynamic> item, MetaItem meta) {
  final tokens = <String>{};

  final open = meta.open;
  if (open != null) {
    final surface = open.surface.trim();
    if (surface == 'tmdb') {
      tokens.add(tmdbCatalogTypeToken(meta));
    } else if (surface.isNotEmpty) {
      tokens.add(surface);
    }
    final rt = open.effectiveExtract.resolveType.trim();
    if (rt.isNotEmpty && rt != 'tmdb') tokens.add(rt);
  }

  final mt = item['mediaType']?.toString() ?? '';
  if (mt == 'movie') tokens.add('movie');
  if (mt == 'tv' || mt == 'series') tokens.add('tv');

  final kind = item['kind']?.toString() ?? '';
  if (kind == 'movie') tokens.add('movie');
  if (kind == 'tv') tokens.add('tv');

  return tokens;
}

bool _typesIntersect(List<String> types, Set<String> tokens) {
  for (final t in types) {
    if (tokens.contains(t)) return true;
  }
  return false;
}

/// Host My List → hub open binding (RFC-108).
abstract final class ListOpenBinding {
  ListOpenBinding._();

  /// Nav label of hub [pluginId] (e.g. `Kids`) — stamped on bookmarks so
  /// My List shows the hub a title was pinned in.
  static Future<String?> hubLabelOf(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return null;
    try {
      final plugins =
          PluginNavRegistry.peekKitPlugins() ??
          await PluginNavRegistry.listKitPlugins();
      for (final pl in plugins) {
        if (pl.id == want) return PackHubSelectOptions.labelFor(pl);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<ListOpenCandidate>> candidatesFor({
    required Map<String, dynamic> item,
    required MetaItem meta,
    bool allDetailsHubs = false,
  }) async {
    final tokens = listOpenIdentityTokens(item, meta);
    final out = <ListOpenCandidate>[];
    for (final pl in await PluginNavRegistry.listKitPlugins()) {
      if (!PackHubSelectOptions.isBrowseHub(pl)) continue;
      final compatible = tokens.isNotEmpty && _typesIntersect(pl.types, tokens);
      if (!allDetailsHubs && tokens.isNotEmpty && !compatible) continue;
      out.add(
        ListOpenCandidate(
          pluginId: pl.id,
          label: PackHubSelectOptions.labelFor(pl),
          types: List<String>.from(pl.types),
          compatible: compatible,
          hasSearch: pl.hasCapability('search'),
        ),
      );
    }
    if (out.isEmpty && !allDetailsHubs) {
      return candidatesFor(item: item, meta: meta, allDetailsHubs: true);
    }
    out.sort((a, b) {
      if (a.compatible != b.compatible) return a.compatible ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return out;
  }

  /// Per-title hub bind on the row (`pluginId` + open id) — not type Auto.
  static Future<({String pluginId, MetaItem meta})?> resolveStored({
    required Map<String, dynamic> item,
    required MetaItem meta,
  }) async {
    final open = meta.open;
    if (open == null) return null;
    final id = open.id.trim();
    if (id.isEmpty) return null;
    final fromRow = item['pluginId']?.toString().trim() ?? '';
    if (fromRow.isNotEmpty &&
        await PluginNavRegistry.pluginHasDetails(fromRow)) {
      return (pluginId: fromRow, meta: meta);
    }
    return null;
  }

  /// Settings default when row has compatible ids and no per-title hub bind.
  static Future<({String pluginId, MetaItem meta})?> resolveDefault({
    required Map<String, dynamic> item,
    required MetaItem meta,
  }) async {
    final tokens = listOpenIdentityTokens(item, meta);
    if (tokens.isEmpty) return null;
    for (final token in tokens) {
      final preferred = await ListOpenPrefs.defaultPluginId(token);
      if (preferred == null || preferred.isEmpty) continue;
      if (!await PluginNavRegistry.pluginHasDetails(preferred)) continue;
      EnginePlugin? pl;
      for (final p in await PluginNavRegistry.listKitPlugins()) {
        if (p.id == preferred) {
          pl = p;
          break;
        }
      }
      if (pl == null || !_typesIntersect(pl.types, tokens)) continue;
      final open = metaOpenForCandidate(item, meta, pl.types);
      if (open == null || open.id.trim().isEmpty) continue;
      return (pluginId: preferred, meta: meta.copyWith(open: open));
    }
    return null;
  }

  /// First details hub for the row's engine type (settings Auto).
  static Future<({String pluginId, MetaItem meta})?> resolveEngineFallback({
    required Map<String, dynamic> item,
    required MetaItem meta,
  }) async {
    final open = meta.open;
    if (open == null) return null;
    if (open.id.trim().isEmpty) return null;
    final surface = open.surface.trim();
    final String typeToken;
    if (surface == 'tmdb') {
      typeToken = tmdbCatalogTypeToken(meta);
    } else if (surface.isNotEmpty) {
      typeToken = surface;
    } else {
      return null;
    }
    if (typeToken.isEmpty) return null;
    final resolved = await PluginNavRegistry.pluginIdForEngineType(typeToken);
    if (resolved == null ||
        resolved.isEmpty ||
        !await PluginNavRegistry.pluginHasDetails(resolved)) {
      return null;
    }
    return (pluginId: resolved, meta: meta);
  }

  /// Build pack [MetaOpen] for a chosen hub from row identity (no search).
  static MetaOpen? metaOpenForCandidate(
    Map<String, dynamic> item,
    MetaItem meta,
    List<String> hubTypes,
  ) {
    final tokens = listOpenIdentityTokens(item, meta);
    final existing = meta.open;
    if (existing != null) {
      final s = existing.surface.trim();
      final rt = existing.effectiveExtract.resolveType.trim();
      if (hubTypes.contains(s) || hubTypes.contains(rt)) return existing;
      if (s == 'tmdb' &&
          (hubTypes.contains('movie') || hubTypes.contains('tv'))) {
        return existing;
      }
    }

    if ((hubTypes.contains('movie') && tokens.contains('movie')) ||
        (hubTypes.contains('tv') && tokens.contains('tv'))) {
      final tmdb = legacyListTmdbId(item) ?? meta.numericId('tmdb');
      if (tmdb == null || tmdb <= 0) return null;
      final mt = hubTypes.contains('tv') && tokens.contains('tv')
          ? 'tv'
          : (tokens.contains('tv') ? 'tv' : 'movie');
      return MetaOpen(
        surface: 'tmdb',
        id: '$tmdb',
        extract: MetaOpenExtract(
          resolveType: mt,
          panelCategory: mt,
          ctx: {'tmdbId': tmdb},
        ),
        extras: {'mediaType': mt},
      );
    }

    return null;
  }

  /// Home-like hub with movie/tv search — used to match TMDB for Simkl.
  static Future<ListOpenCandidate?> tmdbSearchCandidate() async {
    ListOpenCandidate? fallback;
    for (final pl in await PluginNavRegistry.listKitPlugins()) {
      if (!PackHubSelectOptions.isBrowseHub(pl)) continue;
      if (!pl.hasCapability('search')) continue;
      final hasMovie = pl.types.contains('movie');
      final hasTv = pl.types.contains('tv');
      if (!hasMovie && !hasTv) continue;
      final c = ListOpenCandidate(
        pluginId: pl.id,
        label: PackHubSelectOptions.labelFor(pl),
        types: List<String>.from(pl.types),
        compatible: true,
        hasSearch: true,
      );
      if (hasMovie && hasTv) return c;
      fallback ??= c;
    }
    return fallback;
  }

  /// Write TMDB onto the bookmark for Simkl without changing hub open.
  static Future<bool> persistSimklTmdbLink({
    required Map<String, dynamic> item,
    required MetaItem hit,
  }) async {
    final tmdb =
        hit.numericId('tmdb') ??
        (hit.open?.surface.trim() == 'tmdb' ? hit.open?.idInt : null);
    if (tmdb == null || tmdb <= 0) return false;
    final uid = item['uniqueId']?.toString().trim() ?? '';
    if (uid.isEmpty) return false;
    final mt =
        BookmarkStore.normalizeTmdbMediaType(
          hit.tmdbMediaType ??
              hit.open?.effectiveExtract.resolveType ??
              item['tmdbMediaType']?.toString() ??
              item['mediaType']?.toString(),
        ) ??
        'tv';
    await BookmarkStore().patchTmdbLink(
      uniqueId: uid,
      tmdbId: tmdb,
      tmdbMediaType: mt,
    );
    item['tmdbId'] = tmdb;
    item['tmdbMediaType'] = mt;
    final nested = item['meta'];
    if (nested is Map) {
      final ids = Map<String, dynamic>.from(
        (nested['ids'] is Map)
            ? Map<String, dynamic>.from(nested['ids'] as Map)
            : {},
      );
      ids['tmdb'] = tmdb;
      nested['ids'] = ids;
      nested['tmdbMediaType'] = mt;
    }
    final status = item['listStatus']?.toString().trim();
    final to = (status != null && status.isNotEmpty)
        ? status
        : BookmarkStore.defaultStatus;
    if (await SimklService().isLoggedIn()) {
      return (await SimklService().setListStatus(
        tmdbId: tmdb,
        mediaType: mt,
        to: to,
      )).ok;
    }
    return true;
  }

  static Future<void> persistBinding({
    required Map<String, dynamic> item,
    required String pluginId,
    required MetaOpen open,
    required MetaItem meta,
  }) async {
    await BookmarkStore().ensureLoaded();
    final newUid = BookmarkStore.catalogEntryId(pluginId, open.id);
    final oldUid = item['uniqueId']?.toString();
    // Prefer existing bookmark TMDB when the hub hit has none (Afflem open).
    final tmdb = meta.numericId('tmdb') ?? legacyListTmdbId(item);
    final tmdbMt =
        meta.tmdbMediaType ??
        item['tmdbMediaType']?.toString() ??
        (open.surface == 'tmdb' ? open.effectiveExtract.resolveType : null);
    // Hub bind must not reset list status. Prefer an existing bookmark
    // (tmdb_* or catalog_*), then the row's status (Simkl tab), then default.
    final resolveMt =
        BookmarkStore.normalizeTmdbMediaType(
          tmdbMt ?? item['mediaType']?.toString(),
        ) ??
        item['mediaType']?.toString();
    final existingStatus = BookmarkStore().resolvedStatus(
      uniqueId: (oldUid != null && oldUid.isNotEmpty) ? oldUid : newUid,
      tmdbId: tmdb,
      mediaType: resolveMt,
    );
    final rowStatus = item['listStatus']?.toString().trim();
    final status =
        existingStatus ??
        (rowStatus != null && rowStatus.isNotEmpty
            ? rowStatus
            : BookmarkStore.defaultStatus);
    if (oldUid != null && oldUid.isNotEmpty && oldUid != newUid) {
      await BookmarkStore().remove(oldUid);
    }
    await BookmarkStore().upsertCatalog(
      pluginId: pluginId,
      open: open.toJson(),
      uniqueId: newUid,
      mediaType:
          item['mediaType']?.toString() ??
          (meta.type.isNotEmpty
              ? meta.type
              : open.effectiveExtract.panelCategory),
      title: meta.name,
      posterPath: meta.poster,
      listStatus: status,
      tmdbId: tmdb,
      tmdbMediaType: tmdbMt,
      voteAverage: meta.rating ?? 0,
      releaseDate: meta.releaseInfo,
      hubLabel: await hubLabelOf(pluginId),
    );
    item['pluginId'] = pluginId;
    item['uniqueId'] = newUid;
    item['metaOpen'] = open.toJson();
    item['open'] = open.toJson();
    item['catalogOpen'] = open.toJson();
    item['listStatus'] = status;
    if (tmdb != null) {
      item['tmdbId'] = tmdb;
      if (tmdbMt != null && tmdbMt.trim().isNotEmpty) {
        item['tmdbMediaType'] = tmdbMt;
      }
    }
    final title = meta.name.trim();
    if (title.isNotEmpty) {
      item['title'] = title;
      item['name'] = title;
    }
    final poster = meta.poster.trim();
    if (poster.isNotEmpty) {
      item['poster'] = poster;
      item['posterPath'] = poster;
    }
    final bg = meta.background.trim();
    if (bg.isNotEmpty) {
      item['background'] = bg;
      item['backdropPath'] = bg;
    }
    final nested = item['meta'];
    if (nested is Map) {
      nested['open'] = open.toJson();
      if (title.isNotEmpty) nested['name'] = title;
      if (poster.isNotEmpty) nested['poster'] = poster;
      if (bg.isNotEmpty) nested['background'] = bg;
      if (tmdb != null) {
        final ids = Map<String, dynamic>.from(
          (nested['ids'] is Map)
              ? Map<String, dynamic>.from(nested['ids'] as Map)
              : {},
        );
        ids['tmdb'] = tmdb;
        nested['ids'] = ids;
        if (tmdbMt != null && tmdbMt.trim().isNotEmpty) {
          nested['tmdbMediaType'] = tmdbMt;
        }
      }
    }
  }
}
