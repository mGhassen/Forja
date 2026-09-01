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

      final enriched = await CatalogRuntime.instance.enrichLegacyListItems(
        sourcePluginId: myListHubPluginId,
        items: merged,
      );

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
