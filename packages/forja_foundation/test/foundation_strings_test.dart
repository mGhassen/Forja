import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/l10n/foundation_strings.dart';
import 'package:forja_foundation/widgets/details/episode_air_date.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';

const _long =
    'A long synopsis that certainly does not fit on one line of a narrow '
    'column, so the widget has to truncate it and show a read more row.';

Widget _host({ForjaFoundationStrings? strings, String? readMoreLabel}) {
  Widget body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 160,
      child: HeroOverviewText(
        overview: _long,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        readMoreLabel: readMoreLabel,
      ),
    ),
  );
  if (strings != null) {
    body = ForjaFoundationStringsScope(strings: strings, child: body);
  }
  return MaterialApp(home: Scaffold(body: body));
}

const _rows = [
  (label: 'Release Date', value: 'Oct 27, 2026'),
  (label: 'Status', value: 'Released'),
  (label: 'Production', value: 'Bavaria Fiction'),
];

const _fr = ForjaFoundationStrings(
  factLabels: {'Release Date': 'Date de sortie', 'Status': 'Statut'},
  statusLabels: {'Released': 'Sorti'},
  shortMonths: [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ],
  datePattern: '{day} {month} {year}',
);

Widget _facts({ForjaFoundationStrings? strings}) {
  Widget body = const FactsPanel(rows: _rows);
  if (strings != null) {
    body = ForjaFoundationStringsScope(strings: strings, child: body);
  }
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, child: body)),
    ),
  );
}

void factsTests() {
  testWidgets('facts panel stays English without a scope', (tester) async {
    await tester.pumpWidget(_facts());
    expect(find.text('Release Date'), findsOneWidget);
    expect(find.text('Oct 27, 2026'), findsOneWidget);
    expect(find.text('Released'), findsOneWidget);
  });

  testWidgets('facts panel labels, status and date follow the scope', (
    tester,
  ) async {
    await tester.pumpWidget(_facts(strings: _fr));
    expect(find.text('Date de sortie'), findsOneWidget);
    expect(find.text('27 oct. 2026'), findsOneWidget);
    expect(find.text('Statut'), findsOneWidget);
    expect(find.text('Sorti'), findsOneWidget);
    // Not in any map: shown as given.
    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Bavaria Fiction'), findsOneWidget);
    expect(find.text('Release Date'), findsNothing);
  });
}

void main() {
  factsTests();
  test('defaults are English and equal by value', () {
    expect(ForjaFoundationStrings.english.readMore, 'Read More');
    expect(ForjaFoundationStrings.english.all, 'All');
    expect(const ForjaFoundationStrings(), ForjaFoundationStrings.english);
    expect(
      const ForjaFoundationStrings(readMore: 'Lire la suite'),
      isNot(ForjaFoundationStrings.english),
    );
  });

  testWidgets('without a scope the widget shows English', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Read More'), findsOneWidget);
  });

  testWidgets('a scope changes the text', (tester) async {
    await tester.pumpWidget(
      _host(strings: const ForjaFoundationStrings(readMore: 'Lire la suite')),
    );
    expect(find.text('Lire la suite'), findsOneWidget);
    expect(find.text('Read More'), findsNothing);
  });

  testWidgets('a label passed by the caller wins over the scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        strings: const ForjaFoundationStrings(readMore: 'Lire la suite'),
        readMoreLabel: 'Plus',
      ),
    );
    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Lire la suite'), findsNothing);
  });

  group('words and the current strings', () {
    tearDown(
      () => ForjaFoundationStrings.current = ForjaFoundationStrings.english,
    );

    test('t() translates known words and keeps the English for the rest', () {
      const fr = ForjaFoundationStrings(words: {'See all': 'Voir tout'});
      expect(fr.t('See all'), 'Voir tout');
      expect(fr.t('Reload'), 'Reload');
      expect(ForjaFoundationStrings.english.t('See all'), 'See all');
    });

    test(
      'episode dates stay "Oct 31, 2026" in English and follow the app language',
      () {
        expect(formatEpisodeDisplayDate('2026-10-31'), 'Oct 31, 2026');
        ForjaFoundationStrings.current = const ForjaFoundationStrings(
          shortMonths: [
            'janv.',
            'févr.',
            'mars',
            'avr.',
            'mai',
            'juin',
            'juil.',
            'août',
            'sept.',
            'oct.',
            'nov.',
            'déc.',
          ],
          datePattern: '{day} {month} {year}',
        );
        expect(formatEpisodeDisplayDate('2026-10-31'), '31 oct. 2026');
        expect(formatEpisodeDisplayDate('nonsense'), 'nonsense');
      },
    );

    test('list status labels follow the current strings', () {
      expect(listStatusLabel('plantowatch'), 'Plan to Watch');
      ForjaFoundationStrings.current = const ForjaFoundationStrings(
        words: {'Plan to Watch': 'À regarder'},
      );
      expect(listStatusLabel('plantowatch'), 'À regarder');
      expect(listStatusLabel('hold'), 'On Hold');
    });

    test('money and runtime follow the current strings', () {
      Map<String, String> value(String label) => {
        for (final r in factsRowsFromFields(
          title: 'T',
          mediaType: 'movie',
          runtimeMinutes: 97,
          budget: 60000000,
        ))
          r.label: r.value,
      };
      expect(value('x')['Budget'], r'$60,000,000');
      expect(value('x')['Runtime'], '1h 37m');
      ForjaFoundationStrings.current = const ForjaFoundationStrings(
        words: {
          'runtime hours': '\u00a0h',
          'runtime minutes': '\u00a0min',
          'thousands separator': 'space',
          'money symbol': '\u00a0\$',
          'money symbol place': 'after',
        },
      );
      expect(value('x')['Budget'], '60\u00a0000\u00a0000\u00a0\$');
      expect(value('x')['Runtime'], '1\u00a0h 37\u00a0min');
    });
  });
}
