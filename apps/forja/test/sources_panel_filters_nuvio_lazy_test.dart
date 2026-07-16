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

    testWidgets('labels the next network provider count', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourcesLoadNextProviderButton(
              remainingProviders: 3,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Load next provider (3 left)'), findsOneWidget);
      await tester.tap(find.byType(SourcesLoadNextProviderButton));
      expect(pressed, isTrue);
    });

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
