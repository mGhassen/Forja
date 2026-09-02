import 'dart:async';

import 'package:flutter/foundation.dart';
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

final Set<String> _myListEnrichInflight = {};

@visibleForTesting
void clearMyListEnrichCache() {
  _myListEnrichCache.clear();
  _myListEnrichInflight.clear();
}

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
    'anilistId',
    'kisskhId',
    'tmdbId',
    'pluginId',
    'catalogOpen',
  ]) {
    final v = current[key];
    if (v != null) out[key] = v;
  }
  return out;
}

/// Sync cache apply — raw rows until enrich finishes in the background.
@visibleForTesting
List<Map<String, dynamic>> applyMyListEnrichCacheSync(
  List<Map<String, dynamic>> merged,
) {
  if (merged.isEmpty) return merged;
  return [
    for (final row in merged)
      if (_myListEnrichCache[myListEnrichCacheKey(row)] case final cached?)
        _overlayListFields(cached, row)
      else
        Map<String, dynamic>.from(row),
  ];
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

/// Bumps after background enrich so the sync page re-reads the cache.
final myListEnrichEpochProvider =
    NotifierProvider<MyListEnrichEpochNotifier, int>(
      MyListEnrichEpochNotifier.new,
    );

class MyListEnrichEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;

  void scheduleEnrich(List<Map<String, dynamic>> merged) {
    final misses = <Map<String, dynamic>>[];
    for (final row in merged) {
      final key = myListEnrichCacheKey(row);
      if (_myListEnrichCache.containsKey(key)) continue;
      if (!_myListEnrichInflight.add(key)) continue;
      misses.add(row);
    }
    if (misses.isEmpty) return;
    unawaited(() async {
      try {
        await enrichMyListRowsWithCache(misses);
        bump();
      } catch (e, st) {
        debugPrint('[MyList] background enrich failed: $e\n$st');
      } finally {
        for (final row in misses) {
          _myListEnrichInflight.remove(myListEnrichCacheKey(row));
        }
      }
    }());
  }
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

/// Sync page from local (+ Simkl cache). Status pin changes update the grid
/// immediately — no FutureProvider loading gap that keeps a stale card.
final myListCatalogProvider =
    Provider.family<AsyncValue<MyListCatalogPage>, String>((ref, status) {
      ref.watch(myListRevisionProvider);
      ref.watch(myListEnrichEpochProvider);
      final localItems = ref.watch(myListItemsProvider);
      final hiddenKeys = ref.watch(myListHiddenKeysProvider);
      final gateAsync = ref.watch(externalListsGateProvider);

      if (gateAsync.isLoading && !gateAsync.hasValue) {
        return const AsyncLoading();
      }
      if (gateAsync.hasError && !gateAsync.hasValue) {
        return AsyncError(gateAsync.error!, gateAsync.stackTrace!);
      }

      final simklLoggedIn = gateAsync.valueOrNull?.simklLoggedIn == true;

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

      final enriched = applyMyListEnrichCacheSync(merged);
      final pendingEnrich = List<Map<String, dynamic>>.from(merged);
      Future.microtask(() {
        try {
          ref
              .read(myListEnrichEpochProvider.notifier)
              .scheduleEnrich(pendingEnrich);
        } catch (_) {}
      });

      return AsyncData(
        myListCatalogPageFromRows(
          enriched,
          status,
          loadingSimkl: loadingSimkl,
        ),
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
    ref.invalidate(myListEnrichEpochProvider);
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
