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
  group('LayoutArtifact', () {
    test('maps kit.* and section slots', () {
      expect(layoutArtifactFor('kit.stack'), LayoutArtifact.stack);
      expect(layoutArtifactFor('menu'), LayoutArtifact.menu);
      expect(layoutArtifactFor('hero'), LayoutArtifact.hero);
      expect(layoutArtifactFor('mood'), LayoutArtifact.mood);
      expect(
        layoutArtifactFor('continue'),
        LayoutArtifact.continueWatching,
      );
      expect(layoutArtifactFor('because'), LayoutArtifact.because);
      expect(
        layoutArtifactFor('vertical_filters'),
        LayoutArtifact.verticalFilters,
      );
      expect(layoutArtifactFor('unknown.slot'), isNull);
      expect(LayoutArtifact.hero.id, LayoutArtifactId.hero);
      expect(
        LayoutMap.slotToArtifactName[LayoutTypes.hero],
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
            topBar: TopBar(title: 'Home'),
            body: Center(child: Text('Body')),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });
  });
}
