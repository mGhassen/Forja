import 'package:forja/features/asian_drama/asian_drama_country_categories.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shell/shell_bus.dart';

bool dramaCardIsFilm(KdramaCard card) {
  return (card.type ?? '').toLowerCase() == 'movie';
}

bool dramaCardIsSeries(KdramaCard card) {
  return (card.type ?? '').toLowerCase() == 'tvseries';
}

bool dramaCardMatchesMediaFilter(
  KdramaCard card,
  ShellHomeCategory? filter,
) {
  if (filter == null) return true;
  if (filter == ShellHomeCategory.films) return dramaCardIsFilm(card);
  return dramaCardIsSeries(card);
}

List<KdramaCard> filterDramaCardsByMedia(List<KdramaCard> cards) {
  final filter = ShellBus.asianDramaCategory.value;
  return cards.where((c) => dramaCardMatchesMediaFilter(c, filter)).toList();
}

/// Explore `type` code: 0=All, 1=TVSeries, 2=Movie.
int asianDramaExploreTypeCode() {
  final filter = ShellBus.asianDramaCategory.value;
  if (filter == ShellHomeCategory.films) return 2;
  if (filter == ShellHomeCategory.tvShows) return 1;
  return 0;
}

int? asianDramaActiveCountryCode() =>
    asianDramaCountryExploreCode(ShellBus.asianDramaSelectedCountryId.value);
