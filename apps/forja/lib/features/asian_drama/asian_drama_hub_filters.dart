import 'package:forja/features/asian_drama/asian_drama_country_categories.dart';
import 'package:forja/shell/shell_bus.dart';

/// Explore `type` code: 0=All, 1=TVSeries, 2=Movie.
int asianDramaExploreTypeCode() {
  final filter = ShellBus.asianDramaCategory.value;
  if (filter == ShellHomeCategory.films) return 2;
  if (filter == ShellHomeCategory.tvShows) return 1;
  return 0;
}

int? asianDramaActiveCountryCode() =>
    asianDramaCountryExploreCode(ShellBus.asianDramaSelectedCountryId.value);

/// Films / Series / country need KissKH explore — home rails omit `type`.
bool asianDramaHubFilterActive() =>
    asianDramaActiveCountryCode() != null ||
    ShellBus.asianDramaCategory.value != null;
