import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/anime/anime_genre_categories.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shell/shell_bus.dart';

bool animeCardIsFilm(AnimeCard card) {
  return (card.format ?? '').toUpperCase() == 'MOVIE';
}

bool animeCardMatchesMediaFilter(
  AnimeCard card,
  ShellHomeCategory? filter,
) {
  if (filter == null) return true;
  final isFilm = animeCardIsFilm(card);
  if (filter == ShellHomeCategory.films) return isFilm;
  return !isFilm;
}

bool animeCardMatchesGenreFilter(AnimeCard card, String? genreId) {
  final label = animeGenreLabel(genreId);
  if (label == null) return true;
  final needle = label.toLowerCase();
  return card.genres.any((g) => g.toLowerCase() == needle);
}

bool animeCardMatchesHubFilters(AnimeCard card) {
  return animeCardMatchesMediaFilter(card, ShellBus.animeCategory.value) &&
      animeCardMatchesGenreFilter(card, ShellBus.animeSelectedGenreId.value);
}

List<AnimeCard> filterAnimeCards(List<AnimeCard> cards) {
  return cards.where(animeCardMatchesHubFilters).toList();
}

Future<List<AnimeCard>> filterAnimeFuture(Future<List<AnimeCard>> future) {
  return future.then(filterAnimeCards);
}

/// AniList query knobs for the Anime hub top menu (Films / Series / Categories).
({String? genre, String? format, bool excludeMovies}) animeHubListFilters() {
  final category = ShellBus.animeCategory.value;
  final genre = animeGenreLabel(ShellBus.animeSelectedGenreId.value);
  return (
    genre: genre,
    format: category == ShellHomeCategory.films ? 'MOVIE' : null,
    excludeMovies: category == ShellHomeCategory.tvShows,
  );
}

final shellAnimeCategoryProvider =
    NotifierProvider<ShellAnimeCategoryNotifier, ShellHomeCategory?>(
  ShellAnimeCategoryNotifier.new,
);

class ShellAnimeCategoryNotifier extends Notifier<ShellHomeCategory?> {
  @override
  ShellHomeCategory? build() {
    final n = ShellBus.animeCategory;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

final shellAnimeGenreIdProvider =
    NotifierProvider<ShellAnimeGenreIdNotifier, String?>(
  ShellAnimeGenreIdNotifier.new,
);

class ShellAnimeGenreIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final n = ShellBus.animeSelectedGenreId;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}
