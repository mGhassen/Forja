import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initRustForAppTests();
  });

  group('ProviderScoringPanel', () {
    testWidgets('shows tabbed panel with score and tries labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProviderScoringPanel(
                streamCatalog: const {
                  'videasy': 'Videasy',
                  'vidlink': 'VidLink',
                },
                streamOrder: const ['videasy', 'vidlink'],
                onStreamOrderChanged: (_) {},
                onStreamOrderReset: () {},
                animeCatalog: const {'miruro:bee': 'Miruro'},
                animeOrder: const ['miruro:bee'],
                onAnimeOrderChanged: (_) {},
                onAnimeOrderReset: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Server reliability'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Tries'), findsOneWidget);
      expect(find.text('Videasy'), findsOneWidget);

      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();
      expect(find.text('Miruro'), findsOneWidget);
    });

    testWidgets('tries badge uses auto-try position not effective rank', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProviderScoringPanel(
                streamCatalog: const {
                  'videasy': 'Videasy',
                  'vidlink': 'VidLink',
                },
                streamOrder: const ['videasy', 'vidlink'],
                onStreamOrderChanged: (_) {},
                onStreamOrderReset: () {},
                animeCatalog: const {},
                animeOrder: const [],
                onAnimeOrderChanged: (_) {},
                onAnimeOrderReset: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('1st'), findsOneWidget);
      expect(find.text('2nd'), findsOneWidget);
      expect(find.text('3rd'), findsNothing);
    });
  });
}
