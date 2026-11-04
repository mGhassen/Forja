import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/l10n/foundation_strings.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/cast_section.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';
import 'package:forja_foundation/widgets/details/trailers_section.dart';

const _fr = ForjaFoundationStrings(
  words: {
    'Trailers': 'Bandes-annonces',
    'Official': 'Officielle',
    'Geoblocked': 'Géobloquée',
    'Ends': 'Fin à',
    'clock': '24h',
    'Edit': 'Modifier',
    'Delete': 'Supprimer',
    'Copy share code': 'Copier le code de partage',
    'Favorite': 'Ajouter aux favoris',
    'Director': 'Réalisation',
    'voice': 'voix',
    'uncredited': 'non crédité',
  },
);

Widget _host(Widget child) => MaterialApp(
  home: ForjaFoundationStringsScope(
    strings: _fr,
    child: ShellPaintScope(
      useTvFocus: false,
      scaleOnHover: false,
      usesTvDensity: false,
      focusStyled: (context, {required focused}) => focused,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  setUp(() => ForjaFoundationStrings.current = _fr);
  tearDown(() => ForjaFoundationStrings.current = ForjaFoundationStrings.english);

  testWidgets('the end time is drawn as "Fin à HH:MM"', (tester) async {
    await tester.pumpWidget(
      _host(
        FactsPanel.fromFields(
          title: 'T',
          mediaType: 'movie',
          runtimeMinutes: 97,
          positionMs: 0,
          durationMs: 97 * 60000,
        ),
      ),
    );
    expect(find.textContaining(RegExp(r'Fin à \d\d:\d\d')), findsOneWidget);
    expect(find.textContaining('Ends'), findsNothing);
  });

  testWidgets('trailer heading and badges are drawn in French', (tester) async {
    await tester.pumpWidget(
      _host(
        DetailsTrailersSection(
          trailers: const [
            DetailsTrailerItem(
              key: 'k',
              name: 'Bande-annonce',
              thumbnailUrl: '',
              official: true,
              geoblocked: true,
            ),
          ],
          onTap: (_) {},
        ),
      ),
    );
    expect(find.text('Bandes-annonces'), findsOneWidget);
    expect(find.text('Officielle'), findsOneWidget);
    expect(find.text('Géobloquée'), findsOneWidget);
  });

  testWidgets('crew jobs and credit markers are drawn in French', (tester) async {
    await tester.pumpWidget(
      _host(
        const DetailsCastSection(
          cast: [
            {'name': 'A', 'character': 'Charlie Jones / Other (voice)', 'profilePath': ''},
            {'name': 'B', 'character': 'Director', 'profilePath': ''},
            {'name': 'C', 'character': 'Cop (uncredited)', 'profilePath': ''},
          ],
        ),
      ),
    );
    expect(find.text('Charlie Jones / Other (voix)'), findsOneWidget);
    expect(find.text('Réalisation'), findsOneWidget);
    expect(find.text('Cop (non crédité)'), findsOneWidget);
  });

  test('English credits pass through untouched', () {
    ForjaFoundationStrings.current = ForjaFoundationStrings.english;
    expect(localizeCredit('Director'), 'Director');
    expect(localizeCredit('Mel Jones (voice)'), 'Mel Jones (voice)');
  });

  testWidgets('portal row action tooltips are in French', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 600,
          child: PortalListRow(
            item: const PortalListItem(id: '1', label: 'Portal', subtitle: 'x'),
            onEdit: () {},
            onDelete: () {},
            onCopyShareCode: () async => 'code',
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(PortalListRow)));
    await tester.pumpAndSettle();
    final tips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message)
        .toSet();
    expect(
      tips,
      containsAll(['Ajouter aux favoris', 'Modifier', 'Supprimer', 'Copier le code de partage']),
    );
  });
}
