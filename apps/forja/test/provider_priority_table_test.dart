import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/widgets/provider_priority_table.dart';
import 'package:forja/shared/design/design.dart';

import 'helpers/rust_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initRustForAppTests();
  });

  group('ProviderScoringPanel', () {
    testWidgets('shows tabbed panel with score and tries labels', (
      tester,
    ) async {
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
                disabledStreamProviders: const {'vidlink'},
                onStreamOrderChanged: (_) {},
                onStreamProviderToggle: (_) {},
                onStreamOrderReset: () {},
                animeCatalog: const {'miruro:bee': 'Miruro'},
                animeOrder: const ['miruro:bee'],
                disabledAnimeProviders: const {},
                onAnimeOrderChanged: (_) {},
                onAnimeProviderToggle: (_) {},
                onAnimeOrderReset: () {},
                asianDramaCatalog: const {
                  'kisskh.nl': 'kisskh.nl',
                  'kisskh.co': 'kisskh.co',
                },
                asianDramaOrder: const ['kisskh.nl', 'kisskh.co'],
                disabledAsianDramaProviders: const {'kisskh.co'},
                onAsianDramaOrderChanged: (_) {},
                onAsianDramaProviderToggle: (_) {},
                onAsianDramaOrderReset: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Server reliability'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Asian Drama'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Tries'), findsOneWidget);
      expect(find.text('Videasy'), findsOneWidget);

      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();
      expect(find.text('Miruro'), findsOneWidget);

      await tester.tap(find.text('Asian Drama'));
      await tester.pumpAndSettle();
      expect(find.text('kisskh.nl'), findsOneWidget);
      expect(find.text('kisskh.co'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.byType(ForjaSwitch), findsNothing);
    });

    testWidgets('tries badge uses auto-try position not effective rank', (
      tester,
    ) async {
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
                disabledStreamProviders: const {},
                onStreamOrderChanged: (_) {},
                onStreamProviderToggle: (_) {},
                onStreamOrderReset: () {},
                animeCatalog: const {},
                animeOrder: const [],
                disabledAnimeProviders: const {},
                onAnimeOrderChanged: (_) {},
                onAnimeProviderToggle: (_) {},
                onAnimeOrderReset: () {},
                asianDramaCatalog: const {'kisskh.co': 'kisskh.co'},
                asianDramaOrder: const ['kisskh.co'],
                disabledAsianDramaProviders: const {},
                onAsianDramaOrderChanged: (_) {},
                onAsianDramaProviderToggle: (_) {},
                onAsianDramaOrderReset: () {},
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
