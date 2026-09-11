import 'package:flutter/material.dart'
    hide Switch, Chip, Checkbox, Radio, RadioGroup, ListTile, Tooltip;
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/forja_foundation.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: forjaThemeData(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('KitLayoutArtifact', () {
    test('maps kit.* and section slots', () {
      expect(kitLayoutArtifactFor('kit.stack'), KitLayoutArtifact.stack);
      expect(kitLayoutArtifactFor('menu'), KitLayoutArtifact.menu);
      expect(kitLayoutArtifactFor('hero'), KitLayoutArtifact.hero);
      expect(kitLayoutArtifactFor('mood'), KitLayoutArtifact.mood);
      expect(
        kitLayoutArtifactFor('continue'),
        KitLayoutArtifact.continueWatching,
      );
      expect(kitLayoutArtifactFor('because'), KitLayoutArtifact.because);
      expect(
        kitLayoutArtifactFor('vertical_filters'),
        KitLayoutArtifact.verticalFilters,
      );
      expect(kitLayoutArtifactFor('unknown.slot'), isNull);
      expect(KitLayoutArtifact.hero.id, KitLayoutArtifactId.hero);
      expect(
        KitLayoutMap.slotToArtifactName[KitTypes.hero],
        contains('CatalogHeroSection'),
      );
    });
  });

  group('CatalogHeroSection', () {
    testWidgets('renders title and fires onPlay', (tester) async {
      var played = 0;
      await tester.pumpWidget(
        _wrap(
          CatalogHeroSection(
            title: 'Demo Show',
            onPlay: () => played++,
          ),
        ),
      );
      expect(find.text('Demo Show'), findsOneWidget);
      await tester.tap(find.text('Play'));
      expect(played, 1);
    });
  });

  group('ShellBlock', () {
    testWidgets('composes topBar and body', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ShellBlock(
            topBar: TopBarSlots(title: 'Home'),
            body: Center(child: Text('Body')),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });
  });
}
