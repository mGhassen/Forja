import 'package:flutter/foundation.dart';
import 'package:forja/features/anime/anime_genre_categories.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/shell/catalog_vertical_filters.dart';
import 'package:forja/shell/shell_bus.dart';

/// Shell top-bar Films / Series / Categories → protocol filter leaves.
List<Map<String, dynamic>?> catalogChromeFilters(String? tabId) {
  return switch (tabId) {
    'home' => _home(),
    'anime' => _anime(),
    'asian_drama' => _asianDrama(),
    _ => const [],
  };
}

/// Epoch string so rail [ValueKey]s change when chrome filters flip.
String catalogChromeFilterEpoch(String? tabId) {
  final vertical = CatalogVerticalFiltersRegistry.chromeFilterEpoch(tabId);
  return switch (tabId) {
    'home' =>
      '${ShellBus.homeCategory.value}|${ShellBus.homeSelectedGenreId.value}|$vertical',
    'anime' =>
      '${ShellBus.animeCategory.value}|${ShellBus.animeSelectedGenreId.value}|$vertical',
    'asian_drama' =>
      '${ShellBus.asianDramaCategory.value}|${ShellBus.asianDramaSelectedCountryId.value}|$vertical',
    _ => vertical,
  };
}

Listenable? catalogChromeFilterListenable(String? tabId) {
  final id = tabId?.trim();
  final vertical = id == null || id.isEmpty
      ? null
      : Listenable.merge([
          CatalogVerticalFiltersRegistry.revision,
          CatalogVerticalFiltersRegistry.selectedIdFor(id),
        ]);
  final base = switch (tabId) {
    'home' => Listenable.merge([
        ShellBus.homeCategory,
        ShellBus.homeSelectedGenreId,
      ]),
    'anime' => Listenable.merge([
        ShellBus.animeCategory,
        ShellBus.animeSelectedGenreId,
      ]),
    'asian_drama' => Listenable.merge([
        ShellBus.asianDramaCategory,
        ShellBus.asianDramaSelectedCountryId,
      ]),
    _ => null,
  };
  if (base == null) return vertical;
  if (vertical == null) return base;
  return Listenable.merge([base, vertical]);
}

List<Map<String, dynamic>?> _home() {
  final media = ShellBus.homeCategory.value;
  final type = switch (media) {
    ShellHomeCategory.films => 'movie',
    ShellHomeCategory.tvShows => 'tv',
    null => null,
  };
  final genre = lookupHomeGenre(ShellBus.homeSelectedGenreId.value);
  final genreIds = switch (media) {
    ShellHomeCategory.tvShows => genre?.tvGenres,
    _ => genre?.movieGenres,
  };
  return [
    catalogFilterFromSelection(field: 'type', value: type),
    catalogFilterFromSelection(field: 'genre', value: genreIds),
    CatalogVerticalFiltersRegistry.activeFilterFor('home'),
  ];
}

List<Map<String, dynamic>?> _anime() {
  final media = ShellBus.animeCategory.value;
  return [
    if (media == ShellHomeCategory.films)
      catalogFilterFromSelection(field: 'format', value: 'MOVIE'),
    if (media == ShellHomeCategory.tvShows)
      catalogFilterFromSelection(field: 'format_not', value: 'MOVIE'),
    catalogFilterFromSelection(
      field: 'genre',
      value: animeGenreLabel(ShellBus.animeSelectedGenreId.value),
    ),
  ];
}

List<Map<String, dynamic>?> _asianDrama() {
  final media = ShellBus.asianDramaCategory.value;
  // KissKH explore: 0=All, 1=TVSeries, 2=Movie
  final type = switch (media) {
    ShellHomeCategory.films => '2',
    ShellHomeCategory.tvShows => '1',
    null => null,
  };
  return [
    catalogFilterFromSelection(field: 'type', value: type),
    catalogFilterFromSelection(
      field: 'country',
      value: ShellBus.asianDramaSelectedCountryId.value,
    ),
  ];
}
