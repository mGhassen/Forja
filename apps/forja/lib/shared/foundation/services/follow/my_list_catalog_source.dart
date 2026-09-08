import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/services/follow/my_list_catalog_open.dart';
import 'package:forja/shared/foundation/services/follow/my_list_merge.dart';
import 'package:forja/shared/foundation/services/follow/my_list_host.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/services/meta/runtime.dart';
import 'package:forja/shared/foundation/blocks/shell/legacy_list_item.dart';
import 'package:forja/shared/foundation/services/follow/external_list_providers.dart';
import 'package:forja/shared/foundation/services/follow/list_providers.dart';

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

/// True when TMDB enrich can still fill missing art/meta on [row].
@visibleForTesting
bool myListRowStillNeedsEnrich(Map<String, dynamic> row) {
  final tmdb = myListAsInt(row['tmdbId']);
  if (tmdb == null || tmdb <= 0) return false;
  final poster = row['posterPath']?.toString().trim() ?? '';
  if (poster.isEmpty) return true;
  final title = row['title']?.toString().trim() ?? '';
  if (title.isEmpty) return true;
  final vote = row['voteAverage'];
  if (vote == null) return true;
  if (vote is num && vote == 0) return true;
  return false;
}

bool _myListEnrichFieldUsable(dynamic v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is num) return v != 0;
  return true;
}

/// Merge cached enrich onto a live list row without wiping art with empties.
@visibleForTesting
Map<String, dynamic> overlayMyListEnrichFields(
  Map<String, dynamic> cached,
  Map<String, dynamic> current,
) {
  final out = Map<String, dynamic>.from(cached);
  // Live list / identity — always prefer current when set.
  for (final key in const [
    'listStatus',
    'uniqueId',
    'anilistId',
    'kisskhId',
    'tmdbId',
    'pluginId',
    'metaOpen',
    'open',
    'kind',
    'type',
  ]) {
    final v = current[key];
    if (v != null) out[key] = v;
  }
  // Enrich fields — never replace a filled cache value with '' / 0 from Simkl.
  for (final key in const [
    'title',
    'name',
    'posterPath',
    'backdropPath',
    'voteAverage',
    'releaseDate',
  ]) {
    final v = current[key];
    if (_myListEnrichFieldUsable(v)) out[key] = v;
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
        overlayMyListEnrichFields(cached, row)
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
      out[i] = overlayMyListEnrichFields(cached, row);
    } else {
      missIndexes.add(i);
      missItems.add(row);
    }
  }

  if (missItems.isNotEmpty) {
    final enrichFn = enrich ??
        (items) => MetaRuntime.instance.enrichLegacyListItems(
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
      if (!myListRowStillNeedsEnrich(row)) {
        // Already complete (or no TMDB id) — cache as-is, skip engine.
        _myListEnrichCache[key] = Map<String, dynamic>.from(row);
        continue;
      }
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

class MyListCatalogPage implements KitListPage {
  const MyListCatalogPage({
    required this.films,
    required this.tv,
    required this.anime,
    required this.asianDrama,
    required this.loadingSimkl,
  });

  final List<KitListEntry> films;
  final List<KitListEntry> tv;
  final List<KitListEntry> anime;
  final List<KitListEntry> asianDrama;
  final bool loadingSimkl;

  @override
  int get totalCount =>
      films.length + tv.length + anime.length + asianDrama.length;

  @override
  bool get loadingRemote => loadingSimkl;

  @override
  String? get loadingProgressLabel => null;

  @override
  List<KitListEntry> entriesForKind(String? kind) {
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
  final entries = <KitListEntry>[];
  for (final row in enriched) {
    final meta = metaItemFromLegacyListItem(row);
    final kind = (row['kind'] ?? row['type'] ?? myListItemKind(row))
        .toString();
    entries.add(
      KitListEntry(
        meta: meta,
        legacyRow: row,
        kind: kind.isEmpty ? myListItemKind(row) : kind,
        pluginId: row['pluginId']?.toString(),
        listStatus: row['listStatus']?.toString() ?? status,
      ),
    );
  }

  final films = <KitListEntry>[];
  final tv = <KitListEntry>[];
  final anime = <KitListEntry>[];
  final asianDrama = <KitListEntry>[];
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

/// One-shot: next [myListHubFeedProvider] run bypasses [MetaCache].
final myListForceRefreshProvider = StateProvider<bool>((ref) => false);

/// MetaRuntime `feed` for the my-list hub — pack owns composition via
/// `ctx.host.myList.load`. Watches revision / Simkl gate / hidden keys so pin
/// updates re-run feed. Enrich epoch is applied in [myListCatalogProvider]
/// without re-entering the engine.
final myListHubFeedProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((
  ref,
  status,
) async {
  final revision = ref.watch(myListRevisionProvider);
  ref.watch(externalListsGateProvider);
  final hiddenKeys = ref.watch(myListHiddenKeysProvider);

  var forceRefresh = ref.read(myListForceRefreshProvider);

  var rawItems = <Map<String, dynamic>>[];
  try {
    final env = await MetaRuntime.instance.run(
      pluginId: myListHubPluginId,
      action: 'feed',
      params: {
        'status': status,
        'hiddenKeys': hiddenKeys.toList(),
        // Bust MetaCache when local list revision changes.
        '_rev': revision,
      },
      forceRefresh: forceRefresh,
    );
    if (forceRefresh) {
      ref.read(myListForceRefreshProvider.notifier).state = false;
      forceRefresh = false;
    }
    if (env.ok) {
      final items = env.data?['items'];
      if (items is List) {
        for (final e in items) {
          if (e is Map) {
            final row = Map<String, dynamic>.from(e);
            // Host open adapters still read metaOpen.
            if (row['metaOpen'] == null && row['open'] is Map) {
              row['metaOpen'] = Map<String, dynamic>.from(row['open'] as Map);
            }
            rawItems.add(row);
          }
        }
      }
    }
  } catch (e, st) {
    debugPrint('[my_list] hub feed: $e\n$st');
    if (forceRefresh) {
      ref.read(myListForceRefreshProvider.notifier).state = false;
    }
  }
  return rawItems;
});

/// Thin page over [myListHubFeedProvider] + enrich cache (no second engine hop).
final myListCatalogProvider =
    Provider.family<AsyncValue<MyListCatalogPage>, String>((ref, status) {
  ref.watch(myListEnrichEpochProvider);
  final feed = ref.watch(myListHubFeedProvider(status));
  return feed.when(
    skipLoadingOnReload: true,
    skipLoadingOnRefresh: true,
    data: (rawItems) {
      final enriched = applyMyListEnrichCacheSync(rawItems);
      final pendingEnrich = List<Map<String, dynamic>>.from(rawItems);
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
          loadingSimkl: false,
        ),
      );
    },
    error: (e, st) => AsyncError(e, st),
    loading: () => const AsyncLoading(),
  );
});

/// Thin kit list backend: MetaRuntime feed for the my-list hub pack.
final class MyListCatalogSource extends KitListSource {
  const MyListCatalogSource._();

  static const instance = MyListCatalogSource._();

  @override
  String get id => MyListHost.listSourceId;

  @override
  String? get hubPluginId => myListHubPluginId;

  static AsyncValue<KitListPage> _asListPage(
    AsyncValue<MyListCatalogPage> next,
  ) {
    return next.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (page) => AsyncData<KitListPage>(page),
      error: (e, st) => AsyncError<KitListPage>(e, st),
      loading: () => const AsyncLoading<KitListPage>(),
    );
  }

  @override
  AsyncValue<KitListPage> watchPage(WidgetRef ref, String status) {
    return _asListPage(ref.watch(myListCatalogProvider(status)));
  }

  @override
  AsyncValue<KitListPage> readPage(WidgetRef ref, String status) {
    return _asListPage(ref.read(myListCatalogProvider(status)));
  }

  @override
  void listenPage(
    WidgetRef ref,
    String status,
    void Function(AsyncValue<KitListPage> next) onChange,
  ) {
    ref.listen<AsyncValue<MyListCatalogPage>>(myListCatalogProvider(status),
        (prev, next) {
      onChange(_asListPage(next));
    });
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
    ref.read(myListForceRefreshProvider.notifier).state = true;
    ref.invalidate(myListRevisionProvider);
    ref.invalidate(simklWatchlistProvider);
    ref.invalidate(myListEnrichEpochProvider);
    ref.invalidate(myListHubFeedProvider);
    ref.invalidate(myListCatalogProvider);
  }

  @override
  Future<void> openEntry(
    BuildContext context,
    KitListEntry entry,
  ) =>
      openMyListCatalogEntry(context, entry);

  @override
  Widget? buildEntryPin(
    BuildContext context,
    KitListEntry entry,
    String tabStatus,
  ) =>
      myListEntryPin(context, entry, tabStatus);
}
