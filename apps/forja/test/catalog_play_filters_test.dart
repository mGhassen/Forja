import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/kit/details/catalog_play_filters.dart';
import 'package:forja/shell/shell_bus.dart';

void main() {
  group('catalog play filters', () {
    tearDown(CatalogPackFiltersRegistry.clearForTest);

    test('parses pack filters.play grouped audio', () {
      CatalogPackFiltersRegistry.seedFromJson('test-hub-pack', {
        'play': [
          {
            'id': 'audio',
            'field': 'category',
            'style': 'grouped',
            'default': 'sub',
            'options': [
              {'id': 'sub', 'label': 'SUB', 'value': 'sub'},
              {'id': 'dub', 'label': 'DUB', 'value': 'dub'},
            ],
          },
        ],
      });

      final specs = CatalogPackFiltersRegistry.playFiltersFor('test-hub-pack');
      expect(specs, hasLength(1));
      expect(specs.first.field, 'category');
      expect(specs.first.initialValue(null), 'sub');
      expect(
        specs.first.initialValue({'category': 'dub'}),
        'dub',
      );
      expect(
        catalogPlayAudioCategory({'category': 'dub'}),
        'dub',
      );
    });
  });

  group('pack category filters', () {
    tearDown(() {
      CatalogPackFiltersRegistry.clearForTest();
      ShellBus.hubSelectedCategoryIdFor('home').value = null;
    });

    test('tmdb moods resolve to mood id, not display label', () {
      CatalogPackFiltersRegistry.seedFromJson('tmdb', {
        'fields': [
          {
            'field': 'genre',
            'label': 'Genre',
            'options': [
              {
                'id': 'horror',
                'label': 'Horror',
                'movieGenres': [27],
                'tvGenres': [10765, 9648],
                'filter': {'op': 'eq', 'field': 'mood', 'value': 'horror'},
              },
            ],
          },
        ],
      });

      ShellBus.hubSelectedCategoryIdFor('home').value = 'horror';
      final filters = CatalogPackFiltersRegistry.activeFilters(
        pluginId: 'tmdb',
        tabId: 'home',
      );
      expect(filters, hasLength(1));
      expect(filters.first, {
        'field': 'mood',
        'op': 'eq',
        'value': 'horror',
      });
    });

    test('kisskh countries resolve to country value, not mood id', () {
      CatalogPackFiltersRegistry.seedFromJson('kisskh-hub', {
        'fields': [
          {
            'field': 'country',
            'label': 'Country',
            'options': [
              {
                'id': 'korea',
                'label': 'South Korea',
                'value': '2',
                'filter': {'op': 'eq', 'field': 'country', 'value': '2'},
              },
              {
                'id': 'japan',
                'label': 'Japan',
                'value': '3',
                'filter': {'op': 'eq', 'field': 'country', 'value': '3'},
              },
            ],
          },
        ],
      });

      final categories =
          CatalogPackFiltersRegistry.categoriesFor('kisskh-hub');
      expect(categories.map((e) => e.label), [
        'South Korea',
        'Japan',
      ]);

      ShellBus.hubSelectedCategoryIdFor('asian_drama').value = 'korea';
      final filters = CatalogPackFiltersRegistry.activeFilters(
        pluginId: 'kisskh-hub',
        tabId: 'asian_drama',
      );
      expect(filters, hasLength(1));
      expect(filters.first, {
        'field': 'country',
        'op': 'eq',
        'value': '2',
      });
      ShellBus.hubSelectedCategoryIdFor('asian_drama').value = null;
    });

    test('anime moods resolve to upstream genre name', () {
      CatalogPackFiltersRegistry.seedFromJson('anilist', {
        'fields': [
          {
            'field': 'genre',
            'label': 'Genre',
            'options': [
              {
                'id': 'shonen',
                'label': 'Shōnen',
                'genre': 'Action',
                'filter': {'op': 'eq', 'field': 'genre', 'value': 'Action'},
              },
            ],
          },
        ],
      });

      ShellBus.hubSelectedCategoryIdFor('anime').value = 'shonen';
      final filters = CatalogPackFiltersRegistry.activeFilters(
        pluginId: 'anilist',
        tabId: 'anime',
      );
      expect(filters, hasLength(1));
      expect(filters.first, {
        'field': 'genre',
        'op': 'eq',
        'value': 'Action',
      });
    });

    test('anilist categories list pack genre options', () {
      CatalogPackFiltersRegistry.seedFromJson('anilist', {
        'fields': [
          {
            'field': 'genre',
            'label': 'Genre',
            'options': [
              {
                'id': 'shonen',
                'label': 'Shōnen',
                'filter': {'op': 'eq', 'field': 'genre', 'value': 'Action'},
              },
              {
                'id': 'romance',
                'label': 'Romance',
                'filter': {'op': 'eq', 'field': 'genre', 'value': 'Romance'},
              },
            ],
          },
        ],
        'play': [
          {
            'id': 'audio',
            'field': 'category',
            'style': 'grouped',
            'default': 'sub',
            'options': [
              {'id': 'sub', 'label': 'SUB', 'value': 'sub'},
            ],
          },
        ],
      });

      final categories = CatalogPackFiltersRegistry.categoriesFor('anilist');
      expect(categories.map((e) => e.label), ['Shōnen', 'Romance']);
    });

    test('anime romance uses upstream genre, not mood id', () {
      CatalogPackFiltersRegistry.seedFromJson('anilist', {
        'fields': [
          {
            'field': 'genre',
            'label': 'Genre',
            'options': [
              {
                'id': 'romance',
                'label': 'Romance',
                'genre': 'Romance',
                'filter': {'op': 'eq', 'field': 'genre', 'value': 'Romance'},
              },
            ],
          },
        ],
      });

      ShellBus.hubSelectedCategoryIdFor('anime').value = 'romance';
      final filters = CatalogPackFiltersRegistry.activeFilters(
        pluginId: 'anilist',
        tabId: 'anime',
      );
      expect(filters, hasLength(1));
      expect(filters.first, {
        'field': 'genre',
        'op': 'eq',
        'value': 'Romance',
      });
      ShellBus.hubSelectedCategoryIdFor('anime').value = null;
    });
  });
}
