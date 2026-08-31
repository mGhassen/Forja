import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/catalog_hub_capabilities.dart';
import 'package:forja/shared/catalog/kit/chrome/hub_search_filters.dart';
import 'package:forja/shared/engine/models.dart';

void main() {
  group('CatalogHubCapabilities + EnginePlugin.hasCapability', () {
    EnginePlugin plugin(List<String> caps) => EnginePlugin.fromJson({
          'id': 'test-hub-a',
          'name': 'Test Hub',
          'kind': 'catalog',
          'types': ['movie'],
          'capabilities': caps,
          'entry': 'x.js',
        });

    test('search alone does not imply structured_search', () {
      final p = plugin(const ['nav', 'search', 'filters']);
      expect(p.hasCapability(CatalogHubCapabilities.search), isTrue);
      expect(p.hasCapability(CatalogHubCapabilities.filters), isTrue);
      expect(p.hasCapability(CatalogHubCapabilities.structuredSearch), isFalse);
    });

    test('structured_search is opt-in via capabilities', () {
      final p = plugin(const [
        'search',
        'structured_search',
        'filters',
      ]);
      expect(p.hasCapability(CatalogHubCapabilities.structuredSearch), isTrue);
      expect(p.hasCapability('STRUCTURED_SEARCH'), isTrue);
    });

    test('host_search is separate from structured_search', () {
      final p = plugin(const [
        'search',
        'host_search',
        'structured_search',
      ]);
      expect(p.hasCapability(CatalogHubCapabilities.hostSearch), isTrue);
      expect(p.hasCapability(CatalogHubCapabilities.structuredSearch), isTrue);
    });

    test('missing search capability is false', () {
      final p = plugin(const ['nav', 'rail']);
      expect(p.hasCapability(CatalogHubCapabilities.search), isFalse);
    });
  });

  group('composeSearchQuery', () {
    test('appends lens tokens for pack structured_search', () {
      expect(
        composeSearchQuery(
          'nolan',
          const SearchFilters(
            media: SearchMediaFilter.movie,
            yearStart: 2010,
            yearEnd: 2010,
          ),
        ),
        'nolan films 2010',
      );
    });

    test('filters-only query has no typed prefix', () {
      expect(
        composeSearchQuery(
          '',
          const SearchFilters(minScore: 8, media: SearchMediaFilter.tv),
        ),
        'series >=8',
      );
    });
  });
}
