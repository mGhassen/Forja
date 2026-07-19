import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';

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

    test('respects manual provider pick only when it has streams', () {
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

    test('overrides manual pick when selected addon is empty', () {
      expect(
        promoteStremioProviderId(
          currentId: torrentio,
          addonBaseUrlsInOrder: order,
          loadedIds: {yts},
          completedIds: {torrentio, yts},
          fetching: false,
          userPicked: true,
        ),
        yts,
      );
    });
  });

  group('Nuvio scraper cache', () {
    test('cache preserves attempted scrapers, including empty responses', () {
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
  });

  test('provider options have no All sentinel', () {
    const options = [
      SourcesPanelProviderOption(id: 'forja', label: 'Forja'),
      SourcesPanelProviderOption(id: 'jackett', label: 'Jackett'),
    ];
    expect(options.map((o) => o.id), isNot(contains('all')));
    expect(options.map((o) => o.label.toLowerCase()), isNot(contains('all')));
  });
}
