import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/sources/my_list/my_list_catalog_open.dart';
import 'package:forja/shared/catalog/kit/sources/my_list/my_list_merge.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_list_item.dart';

/// Hub plugin id for the default My List pack (`plugins/hubs/my_list`).
const myListHubPluginId = 'my-list-hub';

/// Enriched legacy rows reused across status-tab rebuilds so a pin change does
/// not re-run the enrich companion for titles already on screen.
final Map<String, Map<String, dynamic>> _myListEnrichCache = {};

@visibleForTesting
void clearMyListEnrichCache() => _myListEnrichCache.clear();

@visibleForTesting
String myListEnrichCacheKey(Map<String, dynamic> row) {
  final uid = row['uniqueId']?.toString().trim() ?? '';
  if (uid.isNotEmpty) return uid;
  final keys = myListItemHideKeys(row);
  if (keys.isNotEmpty) return (keys.toList()..sort()).join('|');
  final title = row['title']?.toString() ?? '';
  final mt = row['mediaType']?.toString() ?? '';
  return 'title:$mt:$title';
}

Map<String, dynamic> _overlayListFields(
  Map<String, dynamic> cached,
  Map<String, dynamic> current,
) {
  final out = Map<String, dynamic>.from(cached);
  for (final key in const [
    'listStatus',
    'uniqueId',
    'title',
    'posterPath',
    'voteAverage',
    'releaseDate',
  ]) {
    final v = current[key];
    if (v != null) out[key] = v;
  }
  return out;
}

/// Apply cached enrich when present; enrich only cache misses.
@visibleForTesting
Future<List<Map<String, dynamic>>> enrichMyListRowsWithCache(
  List<Map<String, dynamic>> merged, {
  Future<List<Map<String, dynamic>>> Function(List<Map<String, dynamic>> items)?
      enrich,
}) async {
  if (merged.isEmpty) return merged;

  final out = List<Map<String, dynamic>?>.filled(merged.length, null);
  final missIndexes = <int>[];
  final missItems = <Map<String, dynamic>>[];

  for (var i = 0; i < merged.length; i++) {
    final row = merged[i];
    final key = myListEnrichCacheKey(row);
    final cached = _myListEnrichCache[key];
    if (cached != null) {
      out[i] = _overlayListFields(cached, row);
    } else {
      missIndexes.add(i);
      missItems.add(row);
    }
  }

  if (missItems.isNotEmpty) {
    final enrichFn = enrich ??
        (items) => CatalogRuntime.instance.enrichLegacyListItems(
              sourcePluginId: myListHubPluginId,
              items: items,
            );
    final enriched = await enrichFn(missItems);
    for (var j = 0; j < missIndexes.length; j++) {
      final fallback = missItems[j];
      final row = j < enriched.length ? enriched[j] : fallback;
      final key = myListEnrichCacheKey(fallback);
      _myListEnrichCache[key] = row;
      final enrichedKey = myListEnrichCacheKey(row);
      if (enrichedKey != key) _myListEnrichCache[enrichedKey] = row;
      out[missIndexes[j]] = row;
    }
  }

  return [for (final row in out) row!];
}

class MyListCatalogPage implements CatalogKitListPage {
  const MyListCatalogPage({
    required this.films,
    required this.tv,
    required this.anime,
    required this.asianDrama,
    required this.loadingSimkl,
  });

  final List<CatalogKitListEntry> films;
  final List<CatalogKitListEntry> tv;
  final List<CatalogKitListEntry> anime;
  final List<CatalogKitListEntry> asianDrama;
  final bool loadingSimkl;

  @override
  int get totalCount =>
      films.length + tv.length + anime.length + asianDrama.length;

  @override
  bool get loadingRemote => loadingSimkl;

  @override
  List<CatalogKitListEntry> entriesForKind(String? kind) {
    if (kind == null) {
      return [...films, ...tv, ...anime, ...asianDrama];
    }
    return switch (kind) {
      'movie' => films,
      'tv' => tv,
      'anime' => anime,
      'asian_drama' => asianDrama,
      _ => const [],
    };
  }
}

@visibleForTesting
MyListCatalogPage myListCatalogPageFromRows(
  List<Map<String, dynamic>> enriched,
  String status, {
  required bool loadingSimkl,
}) {
  final entries = <CatalogKitListEntry>[];
  for (final row in enriched) {
    final meta = catalogMetaFromLegacyListItem(row);
    entries.add(
      CatalogKitListEntry(
        meta: meta,
        legacyRow: row,
        kind: myListItemKind(row),
        pluginId: row['pluginId']?.toString(),
        listStatus: row['listStatus']?.toString() ?? status,
      ),
    );
  }

  final films = <CatalogKitListEntry>[];
  final tv = <CatalogKitListEntry>[];
  final anime = <CatalogKitListEntry>[];
  final asianDrama = <CatalogKitListEntry>[];
  for (final entry in entries) {
    switch (entry.kind) {
      case 'anime':
        anime.add(entry);
      case 'asian_drama':
        asianDrama.add(entry);
      case 'tv':
        tv.add(entry);
      case 'movie':
        films.add(entry);
      default:
        films.add(entry);
    }
  }

  return MyListCatalogPage(
    films: films,
    tv: tv,
    anime: anime,
    asianDrama: asianDrama,
    loadingSimkl: loadingSimkl,
  );
}

final myListCatalogProvider =
    FutureProvider.family<MyListCatalogPage, String>((ref, status) async {
      ref.watch(myListRevisionProvider);
      final localItems = ref.watch(myListItemsProvider);
      final hiddenKeys = ref.watch(myListHiddenKeysProvider);
      final gate = await ref.watch(externalListsGateProvider.future);
      final simklLoggedIn = gate.simklLoggedIn;

      final localForStatus = localItems
          .where(
            (e) => (e['listStatus']?.toString() ?? 'plantowatch') == status,
          )
          .toList();

      var loadingSimkl = false;
      List<Map<String, dynamic>> merged;
      if (simklLoggedIn) {
        final simklAsync = ref.watch(simklWatchlistProvider(status));
        loadingSimkl = simklAsync.isLoading && !simklAsync.hasValue;
        final simklRaw = simklAsync.valueOrNull ?? const [];
        final simklItems = [
          for (final raw in simklRaw) simklCardItem(raw),
        ].whereType<Map<String, dynamic>>().toList();
        final filteredSimkl = filterSimklByLocal(
          simklItems,
          localItems,
          status,
          hiddenKeys,
        );
        merged = mergeLocalHubs(filteredSimkl, localForStatus);
      } else {
        merged = localForStatus;
      }

      final enriched = await enrichMyListRowsWithCache(merged);
      return myListCatalogPageFromRows(
        enriched,
        status,
        loadingSimkl: loadingSimkl,
      );
    });

final class MyListCatalogSource implements CatalogKitListSource {
  const MyListCatalogSource._();

  static const instance = MyListCatalogSource._();

  @override
  String get id => CatalogKitListSources.myList;

  @override
  String? get hubPluginId => myListHubPluginId;

  @override
  AsyncValue<CatalogKitListPage> watchPage(WidgetRef ref, String status) {
    return ref.watch(myListCatalogProvider(status));
  }

  @override
  void setupSideEffects(WidgetRef ref, String status) {
    ref.listen(myListCatalogProvider(status), (prev, next) {
      if (!next.hasValue) return;
      final gate = ref.read(externalListsGateProvider).valueOrNull;
      if (gate?.simklLoggedIn != true) return;
      final cards = [
        for (final entry in next.requireValue.entriesForKind(null))
          entry.legacyRow,
      ];
      ref.read(myListHiddenKeysProvider.notifier).retainOnlyPresentIn(cards);
    });
  }

  @override
  void invalidateOnRefresh(WidgetRef ref) {
    clearMyListEnrichCache();
    ref.invalidate(myListRevisionProvider);
    ref.invalidate(simklWatchlistProvider);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    CatalogKitListEntry entry,
  ) =>
      openMyListCatalogEntry(context, entry);

  @override
  Widget? buildEntryPin(
    BuildContext context,
    CatalogKitListEntry entry,
    String tabStatus,
  ) =>
      myListEntryPin(context, entry, tabStatus);
}
