import 'package:flutter/foundation.dart';
import 'package:forja/features/anime/anime_genre_categories.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shared/catalog/filter.dart';
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
  return switch (tabId) {
    'home' =>
      '${ShellBus.homeCategory.value}|${ShellBus.homeSelectedGenreId.value}',
    'anime' =>
      '${ShellBus.animeCategory.value}|${ShellBus.animeSelectedGenreId.value}',
    'asian_drama' =>
      '${ShellBus.asianDramaCategory.value}|${ShellBus.asianDramaSelectedCountryId.value}',
    _ => '',
  };
}

Listenable? catalogChromeFilterListenable(String? tabId) {
  return switch (tabId) {
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
