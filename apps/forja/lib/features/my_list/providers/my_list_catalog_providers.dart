import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/my_list_merge.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/services/my_list_tmdb_enricher.dart';

class MyListCatalogEntry {
  const MyListCatalogEntry({
    required this.meta,
    required this.legacyRow,
    required this.kind,
    this.pluginId,
    this.listStatus,
  });

  final CatalogMetaItem meta;
  final Map<String, dynamic> legacyRow;
  final String kind;
  final String? pluginId;
  final String? listStatus;
}

class MyListCatalogPage {
  const MyListCatalogPage({
    required this.films,
    required this.tv,
    required this.anime,
    required this.loadingSimkl,
  });

  final List<MyListCatalogEntry> films;
  final List<MyListCatalogEntry> tv;
  final List<MyListCatalogEntry> anime;
  final bool loadingSimkl;

  int get totalCount => films.length + tv.length + anime.length;

  List<MyListCatalogEntry> entriesForKind(String? kind) {
    if (kind == null) {
      return [...films, ...tv, ...anime];
    }
    return switch (kind) {
      'movie' => films,
      'tv' => tv,
      'anime' => anime,
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

      final enriched = await MyListTmdbEnricher.enrichBatch(merged);
      final entries = <MyListCatalogEntry>[];
      for (final row in enriched) {
        final meta = MyListTmdbEnricher.metaFromRow(row);
        final pluginId = row['pluginId']?.toString();
        entries.add(
          MyListCatalogEntry(
            meta: meta,
            legacyRow: row,
            kind: myListItemKind(row),
            pluginId: pluginId,
            listStatus: row['listStatus']?.toString() ?? status,
          ),
        );
      }

      final films = <MyListCatalogEntry>[];
      final tv = <MyListCatalogEntry>[];
      final anime = <MyListCatalogEntry>[];
      for (final entry in entries) {
        switch (entry.kind) {
          case 'anime':
            anime.add(entry);
          case 'tv':
            tv.add(entry);
          default:
            films.add(entry);
        }
      }

      return MyListCatalogPage(
        films: films,
        tv: tv,
        anime: anime,
        loadingSimkl: loadingSimkl,
      );
    });
