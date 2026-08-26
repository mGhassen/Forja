import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shell/shell_bus.dart';

/// KissKH country filters for the Asian Drama hub Categories menu.
/// Ids are explore `country` codes (All / United States omitted).
List<({String id, String label})> get asianDramaCountryCategories => [
      for (final o in KissKhExploreFilters.countryOptions)
        if (o.code != 0) (id: '${o.code}', label: o.label),
    ];

String? asianDramaCountryLabel(String? id) {
  final code = asianDramaCountryExploreCode(id);
  if (code == null) return null;
  return KissKhExploreFilters.countryLabel(code);
}

int? asianDramaCountryExploreCode(String? id) {
  if (id == null) return null;
  final code = int.tryParse(id);
  if (code == null || code <= 0) return null;
  return KissKhExploreFilters.countryOptionIndex(code) == null ? null : code;
}

/// Drop a Categories id that is no longer offered (e.g. removed United States).
void asianDramaSanitizeCountrySelection() {
  final id = ShellBus.asianDramaSelectedCountryId.value;
  if (id != null && asianDramaCountryExploreCode(id) == null) {
    ShellBus.asianDramaSelectedCountryId.value = null;
  }
}
