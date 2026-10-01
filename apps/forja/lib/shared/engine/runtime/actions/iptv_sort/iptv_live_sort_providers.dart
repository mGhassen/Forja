import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';

/// IPTV Live sidebar category order (Playlist / A–Z / Z–A).
final iptvLiveCategorySortProvider =
    StateProvider<PortalCatalogSort>((ref) => PortalCatalogSort.playlist);

/// IPTV Live channel / title order (Playlist / A–Z / Z–A).
final iptvLiveContentSortProvider =
    StateProvider<PortalCatalogSort>((ref) => PortalCatalogSort.playlist);

bool _iptvLiveSortHydrated = false;

/// Load prefs once into the providers (safe to call from multiple chrome mounts).
Future<void> hydrateIptvLiveSortProviders(WidgetRef ref) async {
  if (_iptvLiveSortHydrated) return;
  _iptvLiveSortHydrated = true;
  final category = await PortalStore.loadLiveCategorySort();
  final content = await PortalStore.loadLiveContentSort();
  ref.read(iptvLiveCategorySortProvider.notifier).state = category;
  ref.read(iptvLiveContentSortProvider.notifier).state = content;
}

Future<void> setIptvLiveCategorySort(
  WidgetRef ref,
  PortalCatalogSort sort,
) async {
  if (ref.read(iptvLiveCategorySortProvider) == sort) return;
  ref.read(iptvLiveCategorySortProvider.notifier).state = sort;
  await PortalStore.saveLiveCategorySort(sort);
}

Future<void> setIptvLiveContentSort(
  WidgetRef ref,
  PortalCatalogSort sort,
) async {
  if (ref.read(iptvLiveContentSortProvider) == sort) return;
  ref.read(iptvLiveContentSortProvider.notifier).state = sort;
  await PortalStore.saveLiveContentSort(sort);
}
