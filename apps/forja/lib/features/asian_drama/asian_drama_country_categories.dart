import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';

/// KissKH country filters for the Asian Drama hub Categories menu.
/// Ids are 1-based explore `country` codes (0 = All is omitted).
List<({String id, String label})> get asianDramaCountryCategories {
  final countries = KissKhExploreFilters.countries;
  return [
    for (var i = 1; i < countries.length; i++)
      (id: '$i', label: countries[i]),
  ];
}

String? asianDramaCountryLabel(String? id) {
  if (id == null) return null;
  final index = int.tryParse(id);
  if (index == null ||
      index <= 0 ||
      index >= KissKhExploreFilters.countries.length) {
    return null;
  }
  return KissKhExploreFilters.countries[index];
}

int? asianDramaCountryExploreCode(String? id) {
  if (id == null) return null;
  final index = int.tryParse(id);
  if (index == null ||
      index <= 0 ||
      index >= KissKhExploreFilters.countries.length) {
    return null;
  }
  return index;
}
