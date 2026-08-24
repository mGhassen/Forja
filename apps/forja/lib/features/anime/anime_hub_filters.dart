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
