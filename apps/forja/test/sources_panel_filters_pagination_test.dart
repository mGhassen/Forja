import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';

void main() {
  group('Sources panel page size', () {
    test('kSourcesListPageSize is 10', () {
      expect(kSourcesListPageSize, 10);
    });

    test('visible window clamps to page size then grows by page', () {
      const total = 25;
      var limit = kSourcesListPageSize;
      var visible = total < limit ? total : limit;
      expect(visible, 10);
      expect(visible < total, isTrue);

      limit += kSourcesListPageSize;
      visible = total < limit ? total : limit;
      expect(visible, 20);

      limit += kSourcesListPageSize;
      visible = total < limit ? total : limit;
      expect(visible, 25);
      expect(visible < total, isFalse);
    });
  });

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

  group('SourcesLoadMoreButton', () {
    testWidgets('labels remaining results', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourcesLoadMoreButton(
              remaining: 15,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Load more (15 left)'), findsOneWidget);
      await tester.tap(find.byType(SourcesLoadMoreButton));
      expect(pressed, isTrue);
    });
  });

  group('SourcesPanelProviderOption', () {
    test('carries id and label without an All sentinel', () {
      const options = [
        SourcesPanelProviderOption(id: 'forja', label: 'Forja'),
        SourcesPanelProviderOption(id: 'jackett', label: 'Jackett'),
      ];
      expect(options.map((o) => o.id), isNot(contains('all')));
      expect(options.map((o) => o.label.toLowerCase()), isNot(contains('all')));
    });
  });
}
