import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:rust/rust.dart';

void main() {
  group('TorrentSourceKindFilter', () {
    testWidgets('shows Torrents / Stremio / Nuvio without All', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TorrentSourceKindFilter(
              selected: 'torrents',
              showTorrents: true,
              showStremio: true,
              showNuvio: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Torrents'), findsOneWidget);
      expect(find.text('Stremio'), findsOneWidget);
      expect(find.text('Nuvio'), findsOneWidget);
      expect(find.text('All'), findsNothing);
    });
  });

  group('Nuvio scraper lazy loading', () {
    test('picks the next selected scraper that has not been fetched', () {
      expect(
        nextNuvioScraperId(
          orderedIds: const ['a', 'b', 'c'],
          selectedIds: const {'a', 'c'},
          fetchedIds: const {'a'},
        ),
        'c',
      );
      expect(
        nextNuvioScraperId(
          orderedIds: const ['a', 'b', 'c'],
          selectedIds: const {'a', 'c'},
          fetchedIds: const {'a', 'c'},
        ),
        isNull,
      );
      expect(
        nextNuvioScraperId(
          orderedIds: const ['a', 'b', 'c'],
          selectedIds: const {'a', 'b', 'c'},
          fetchedIds: const {'a'},
        ),
        'b',
      );
    });

    test('provider filter badge ignores all-selected default', () {
      expect(
        nuvioProviderFilterActiveCount(selectedCount: 3, totalEnabled: 3),
        0,
      );
      expect(
        nuvioProviderFilterActiveCount(selectedCount: 0, totalEnabled: 3),
        0,
      );
      expect(
        nuvioProviderFilterActiveCount(selectedCount: 2, totalEnabled: 3),
        2,
      );
    });

    test('filterNuvioSelectedScraperIds drops disabled / unknown ids', () {
      expect(
        filterNuvioSelectedScraperIds(
          savedIds: const ['a', 'gone', 'b'],
          enabledIds: const {'a', 'b', 'c'},
        ),
        {'a', 'b'},
      );
    });

    test('All tap clears every scraper when All is already selected', () {
      expect(
        nextNuvioSelectedAfterAllTap(
          selectedIds: const {'a', 'b'},
          enabledIds: const {'a', 'b'},
        ),
        isEmpty,
      );
      expect(
        nextNuvioSelectedAfterAllTap(
          selectedIds: const {'a'},
          enabledIds: const {'a', 'b'},
        ),
        {'a', 'b'},
      );
      expect(
        nextNuvioSelectedAfterAllTap(
          selectedIds: const {},
          enabledIds: const {'a', 'b'},
        ),
        {'a', 'b'},
      );
    });

    test('scraper tap from full All solos that scraper; otherwise toggles', () {
      expect(
        nextNuvioSelectedAfterScraperTap(
          selectedIds: const {'a', 'b'},
          enabledIds: const {'a', 'b'},
          scraperId: 'a',
        ),
        {'a'},
      );
      expect(
        nextNuvioSelectedAfterScraperTap(
          selectedIds: const {'a'},
          enabledIds: const {'a', 'b'},
          scraperId: 'b',
        ),
        {'a', 'b'},
      );
      expect(
        nextNuvioSelectedAfterScraperTap(
          selectedIds: const {'a', 'b'},
          enabledIds: const {'a', 'b', 'c'},
          scraperId: 'a',
        ),
        {'b'},
      );
    });

    test('All chrome lights only All, not every scraper chip', () {
      const selected = {'a', 'b'};
      const visible = ['a', 'b'];
      expect(
        nuvioProviderChipSelected(
          optionId: 'all_nuvio',
          selectedScraperIds: selected,
          visibleScraperIds: visible,
          allMode: true,
        ),
        isTrue,
      );
      expect(
        nuvioProviderChipSelected(
          optionId: 'nuvio:a',
          selectedScraperIds: selected,
          visibleScraperIds: visible,
          allMode: true,
        ),
        isFalse,
      );
      expect(
        nuvioProviderChipSelected(
          optionId: 'nuvio:a',
          selectedScraperIds: const {'a'},
          visibleScraperIds: visible,
          allMode: false,
        ),
        isTrue,
      );
      expect(
        nuvioProviderChipSelected(
          optionId: 'all_nuvio',
          selectedScraperIds: const {'a'},
          visibleScraperIds: const ['a'],
          allMode: false,
        ),
        isFalse,
      );
    });

    test('walks remaining selected scrapers until the set is exhausted', () {
      expect(
        shouldContinueNuvioScraperWalk(
          explicitScraper: false,
          hasPendingSelected: true,
        ),
        isTrue,
      );
      expect(
        shouldContinueNuvioScraperWalk(
          explicitScraper: false,
          hasPendingSelected: false,
        ),
        isFalse,
      );
      expect(
        shouldContinueNuvioScraperWalk(
          explicitScraper: true,
          hasPendingSelected: true,
        ),
        isFalse,
      );
    });

    test(
      'batches the next unfetched selected scrapers (10 desktop default)',
      () {
        expect(nuvioSourcesBatchLimit(tv: false), 10);
        expect(nuvioSourcesBatchLimit(tv: true), 5);
        expect(
          nextNuvioScraperBatch(
            orderedIds: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
            selectedIds: const {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
            fetchedIds: const {},
          ),
          ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        );
        expect(
          nextNuvioScraperBatch(
            orderedIds: const [
              'a',
              'b',
              'c',
              'd',
              'e',
              'f',
              'g',
              'h',
              'i',
              'j',
              'k',
            ],
            selectedIds: {
              'a',
              'b',
              'c',
              'd',
              'e',
              'f',
              'g',
              'h',
              'i',
              'j',
              'k',
            },
            fetchedIds: const {},
          ),
          ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
        );
        expect(
          nextNuvioScraperBatch(
            orderedIds: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
            selectedIds: const {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
            fetchedIds: const {'a', 'b', 'c', 'd', 'e'},
          ),
          ['f', 'g'],
        );
        expect(
          nextNuvioScraperBatch(
            orderedIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
            selectedIds: const {'b', 'd', 'f'},
            fetchedIds: const {'b'},
          ),
          ['d', 'f'],
        );
      },
    );

    test('missing chip selection defaults to all enabled', () {
      expect(
        resolveNuvioSelectedScraperIds(
          selectionSaved: false,
          savedIds: const [],
          enabledIds: const {'allanime', 'Cineby'},
        ),
        {'allanime', 'Cineby'},
      );
      expect(
        resolveNuvioSelectedScraperIds(
          selectionSaved: false,
          savedIds: const [],
          enabledIds: const {'allanime', 'Cineby'},
          selectAllDefault: false,
        ),
        isEmpty,
      );
      expect(
        resolveNuvioSelectedScraperIds(
          selectionSaved: true,
          savedIds: const [],
          enabledIds: const {'allanime', 'Cineby'},
        ),
        isEmpty,
      );
      expect(
        resolveNuvioSelectedScraperIds(
          selectionSaved: true,
          savedIds: const ['Cineby', 'gone'],
          enabledIds: const {'allanime', 'Cineby'},
        ),
        {'Cineby'},
      );
    });
  });

  group('promoteStremioProviderId', () {
    const torrentio = 'https://torrentio.strem.fun';
    const yts = 'https://ytztvio.example';
    const order = [torrentio, yts];

    test('moves off empty first addon onto one with streams', () {
      expect(
        promoteStremioProviderId(
          currentId: torrentio,
          addonBaseUrlsInOrder: order,
          loadedIds: {yts},
          completedIds: {torrentio, yts},
          fetching: false,
          userPicked: false,
        ),
        yts,
      );
    });

    test('waits for preferred addon while still fetching', () {
      expect(
        promoteStremioProviderId(
          currentId: torrentio,
          preferredId: torrentio,
          addonBaseUrlsInOrder: order,
          loadedIds: {yts},
          completedIds: {yts},
          fetching: true,
          userPicked: false,
        ),
        isNull,
      );
    });

    test('falls back when preferred finished empty', () {
      expect(
        promoteStremioProviderId(
          currentId: torrentio,
          preferredId: torrentio,
          addonBaseUrlsInOrder: order,
          loadedIds: {yts},
          completedIds: {torrentio, yts},
          fetching: false,
          userPicked: false,
        ),
        yts,
      );
    });

    test('respects manual provider pick when it has streams', () {
      expect(
        promoteStremioProviderId(
          currentId: yts,
          addonBaseUrlsInOrder: order,
          loadedIds: {yts},
          completedIds: {torrentio, yts},
          fetching: false,
          userPicked: true,
        ),
        isNull,
      );
    });

    test('keeps manual pick even when selected addon is empty', () {
      expect(
        promoteStremioProviderId(
          currentId: torrentio,
          addonBaseUrlsInOrder: order,
          loadedIds: {yts},
          completedIds: {torrentio, yts},
          fetching: false,
          userPicked: true,
        ),
        isNull,
      );
    });
  });

  group('Nuvio scraper cache', () {
    test('keeps empty nuvio fetches so reopen does not re-hit', () {
      const key = 'nuvio-lazy-test';
      CatalogSourcesSessionCache.writeNuvio(
        key,
        const [],
        fetchedScraperIds: const {'empty-scraper'},
      );

      final cached = CatalogSourcesSessionCache.readNuvio(key);
      expect(cached, isNotNull);
      expect(cached!.streams, isEmpty);
      expect(cached.fetchedScraperIds, {'empty-scraper'});
      CatalogSourcesSessionCache.invalidate(key);
    });

    test('keeps fetched scrapers that returned streams', () {
      const key = 'nuvio-hit-test';
      CatalogSourcesSessionCache.writeNuvio(
        key,
        [
          {
            'url': 'https://example.com/a.m3u8',
            '_nuvioScraperId': 'hit-scraper',
          },
        ],
        fetchedScraperIds: const {'hit-scraper', 'empty-scraper'},
      );

      final cached = CatalogSourcesSessionCache.readNuvio(key);
      expect(cached, isNotNull);
      expect(cached!.streams, isNotEmpty);
      expect(cached.fetchedScraperIds, {'hit-scraper', 'empty-scraper'});
      CatalogSourcesSessionCache.invalidate(key);
    });
  });

  group('Stremio session cache', () {
    test('does not stick empty stremio hits', () {
      const key = 'movie:42';
      CatalogSourcesSessionCache.writeStremio(key, const []);
      expect(CatalogSourcesSessionCache.readStremio(key), isNull);
    });
  });

  group('Engine session cache', () {
    test('keeps empty engine fetches so reopen does not re-hit', () {
      const key = 'anime:7';
      CatalogSourcesSessionCache.writeEngine(
        key,
        const [],
        fetchedPluginIds: const {'videasy'},
      );
      final cached = CatalogSourcesSessionCache.readEngine(key);
      expect(cached, isNotNull);
      expect(cached!.streams, isEmpty);
      expect(cached.fetchedPluginIds, {'videasy'});
      CatalogSourcesSessionCache.invalidate(key);
    });

    test('hub cacheKey prefers anilist over TMDB mediaType flip', () {
      expect(
        CatalogSourcesSessionCache.cacheKey(
          mediaId: 999,
          mediaType: 'tv',
          season: 1,
          episode: 3,
          anilistId: 42,
          animeAudioCategory: 'sub',
        ),
        'anime:42:E3:sub',
      );
      expect(
        CatalogSourcesSessionCache.cacheKey(
          mediaId: -42,
          mediaType: 'anime',
          episode: 3,
          anilistId: 42,
          animeAudioCategory: 'sub',
        ),
        'anime:42:E3:sub',
      );
      expect(
        CatalogSourcesSessionCache.cacheKey(
          mediaId: 55,
          mediaType: 'asian_drama',
          episode: 2,
          kisskhId: 88,
        ),
        'drama:88:E2',
      );
    });
  });

  group('Torrent session cache', () {
    test('does not stick empty torrent hits', () {
      const key = 'tv:1:S1:E3';
      CatalogSourcesSessionCache.writeTorrents(key, const []);
      expect(CatalogSourcesSessionCache.readTorrents(key), isNull);

      CatalogSourcesSessionCache.writeTorrents(key, [
        TorrentResult(
          name: 'Show.S01E03',
          magnet: 'magnet:?xt=urn:btih:abc',
          seeders: '10',
          size: '1 GB',
          source: 'YTS',
        ),
      ]);
      expect(CatalogSourcesSessionCache.readTorrents(key), isNotEmpty);
      CatalogSourcesSessionCache.invalidate(key, kind: 'torrents');
    });
  });

  test('torrent provider chips include All and enabled providers', () {
    final options = torrentProviderChipOptions(
      enabledProviders: const [
        TorrentSearchProviders.knaben,
        TorrentSearchProviders.yts,
      ],
      jackettConfigured: true,
      prowlarrConfigured: false,
    );
    expect(options.map((o) => o.id).toList(), [
      TorrentSearchProviders.allId,
      TorrentSearchProviders.knaben,
      TorrentSearchProviders.yts,
      'jackett',
    ]);
    expect(options.first.label, 'All');
  });

  test('torrent All lights only All, not every builtin chip', () {
    expect(
      torrentProviderChipSelected(
        optionId: TorrentSearchProviders.allId,
        selectedSourceId: TorrentSearchProviders.allId,
      ),
      isTrue,
    );
    expect(
      torrentProviderChipSelected(
        optionId: TorrentSearchProviders.yts,
        selectedSourceId: TorrentSearchProviders.allId,
      ),
      isFalse,
    );
    expect(
      torrentProviderChipSelected(
        optionId: 'jackett',
        selectedSourceId: TorrentSearchProviders.allId,
      ),
      isFalse,
    );
    expect(
      torrentProviderChipSelected(
        optionId: TorrentSearchProviders.knaben,
        selectedSourceId: TorrentSearchProviders.yts,
      ),
      isFalse,
    );
    expect(
      torrentProviderChipSelected(
        optionId: TorrentSearchProviders.allId,
        selectedSourceId: TorrentSearchProviders.noneId,
      ),
      isFalse,
    );
    expect(
      torrentProviderChipSelected(
        optionId: TorrentSearchProviders.yts,
        selectedSourceId: TorrentSearchProviders.noneId,
      ),
      isFalse,
    );
    expect(
      torrentProviderChipSelected(
        optionId: TorrentSearchProviders.yts,
        selectedSourceId: TorrentSearchProviders.yts,
      ),
      isTrue,
    );
  });
}
