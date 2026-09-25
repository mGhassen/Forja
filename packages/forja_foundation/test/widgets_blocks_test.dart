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
        LayoutMap.slotToArtifactName[LayoutTypes.stack],
        'LayoutStack',
      );
      expect(
        LayoutMap.slotToArtifactName[LayoutTypes.hero],
        'CinematicHero',
      );
      expect(LayoutMap.slotToArtifactName.containsKey('iptvCatalog'), isFalse);
    });
  });

  group('ShellBlock', () {
    testWidgets('composes topBar and body', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ShellBlock(
            topBar: ShellTabHeader(title: 'Home'),
            body: Center(child: Text('Body')),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('fromProps reads sideRailWidth', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShellBlock.fromProps(
            {'sideRailWidth': 180},
            body: const Text('Body'),
            sideRail: const Text('Rail'),
          ),
        ),
      );
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Rail'), findsOneWidget);
    });
  });

  group('props_map + block fromProps (RFC-112)', () {
    test('props readers', () {
      expect(propsString({'a': ' x '}, 'a'), 'x');
      expect(propsNumOr({'bottomGap': 24}, 'bottomGap', 0), 24);
      expect(propsBool({'loading': true}, 'loading'), isTrue);
      expect(propsColor({'c': '#FF0000'}, 'c'), const Color(0xFFFF0000));
    });

    testWidgets('CatalogBody.fromProps', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CatalogBody.fromProps(
            {'bottomGap': 8},
            sections: const [Text('Sec')],
          ),
        ),
      );
      expect(find.text('Sec'), findsOneWidget);
    });

    testWidgets('EmptyBlock.fromProps', (tester) async {
      await tester.pumpWidget(
        _wrap(EmptyBlock.fromProps({'title': 'Nothing here'})),
      );
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('MatchDetailsPage.fromProps builds DetailsHero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MatchDetailsPage.fromProps({
            'title': 'Home vs Away',
            'subtitle': 'League',
            'backdropUrl': '',
            'backgroundColor': '#112233',
          }),
        ),
      );
      expect(find.text('Home vs Away'), findsWidgets);
      expect(find.text('League'), findsWidgets);
    });

    testWidgets('DetailsBlock.fromProps builds DetailsHero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DetailsBlock.fromProps({
            'title': 'Show Title',
            'overview': 'Synopsis here',
            'backdropUrl': '',
            'genres': ['Drama'],
          }),
        ),
      );
      expect(find.text('Show Title'), findsWidgets);
      expect(find.text('Synopsis here'), findsWidgets);
    });

    testWidgets('EntryDetails.fromProps', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EntryDetails.fromProps(
            {'title': 'Entry', 'emptyMessage': 'Empty'},
            body: const Text('Panel'),
          ),
        ),
      );
      expect(find.text('Entry'), findsOneWidget);
      expect(find.text('Panel'), findsOneWidget);
    });

    testWidgets('ColumnsHeaderBlock.fromProps builds chrome + rail + empty grid',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ColumnsHeaderBlock.fromProps({
            'sideWidth': 120,
            'actions': [
              {
                'id': 'catalog',
                'label': 'Section',
                'style': 'shelf',
                'default': 'live',
                'items': [
                  {'id': 'live', 'label': 'Live'},
                  {'id': 'movies', 'label': 'Movies'},
                ],
              },
            ],
            'sideItems': [
              {'id': 'all', 'label': 'All'},
              {'id': 'sports', 'label': 'Sports'},
            ],
            'selectedSideId': 'all',
            'emptyTitle': 'No channels',
          }),
        ),
      );
      expect(find.text('Live'), findsWidgets);
      expect(find.text('All'), findsWidgets);
      expect(find.text('Sports'), findsWidgets);
      expect(find.text('No channels'), findsOneWidget);
    });

    testWidgets('TopBodyBlock.fromProps builds chrome + kinds + empty',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TopBodyBlock.fromProps({
            'actions': [
              {'id': 'refresh', 'label': 'Refresh'},
            ],
            'kindItems': [
              {'id': 'all', 'label': 'All'},
              {'id': 'football', 'label': 'Football'},
            ],
            'emptyTitle': 'No matches',
          }),
        ),
      );
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
      expect(find.text('Football'), findsWidgets);
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('TabsCardsBlock stacks menu + tabs + cards', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TabsCardsBlock.fromProps(
            const {},
            menu: const Text('Film'),
            tabs: const Text('Watching'),
            cards: const Center(child: Text('Your list is empty')),
          ),
        ),
      );
      expect(find.text('Film'), findsOneWidget);
      expect(find.text('Watching'), findsOneWidget);
      expect(find.text('Your list is empty'), findsOneWidget);
    });

    testWidgets('TabsCardsBlock drops the menu below the window title', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: forjaThemeData(),
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 34)),
            child: const Scaffold(
              body: TabsCardsBlock(
                menu: Padding(
                  padding: EdgeInsets.only(top: ShellTokens.tabHeaderTopPadding),
                  child: Text('Film'),
                ),
                cards: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      final dy = tester.getTopLeft(find.text('Film')).dy;
      expect(dy, 34 + ShellTokens.shellHeaderTopPadding);
    });

    test('layout_map lists mounted block types', () {
      expect(LayoutMap.slotToArtifactName['catalogBody'], contains('CatalogBody'));
      expect(LayoutMap.slotToArtifactName['columnsHeader'], contains('ColumnsHeader'));
      expect(LayoutMap.slotToArtifactName['topBody'], contains('TopBody'));
      expect(LayoutMap.slotToArtifactName['tabsCards'], contains('TabsCards'));
      expect(LayoutMap.slotToArtifactName['matchDetails'], contains('MatchDetailsPage'));
      expect(LayoutMap.slotToArtifactName.containsKey('iptvCatalog'), isFalse);
    });
  });
}
