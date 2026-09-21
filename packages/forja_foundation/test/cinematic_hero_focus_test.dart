import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';

void main() {
  testWidgets('hero carousel slide keeps action-row FocusNode attached', (
    tester,
  ) async {
    final focus = FocusNode(debugLabel: 'test-hero-cta');
    addTearDown(focus.dispose);
    final key = GlobalKey<CinematicHeroState>();

    Widget actionRow(
      BuildContext context,
      CinematicHeroSlide slide, {
      required bool isActive,
    }) {
      if (!isActive) return const SizedBox.shrink();
      return Focus(
        focusNode: focus,
        child: Text('CTA ${slide.id}'),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            width: 900,
            child: CinematicHero(
              key: key,
              slides: const [
                CinematicHeroSlide(
                  id: 'a',
                  title: 'Alpha',
                  backdropUrl: 'https://example.com/a.jpg',
                  overview: 'First',
                ),
                CinematicHeroSlide(
                  id: 'b',
                  title: 'Beta',
                  backdropUrl: 'https://example.com/b.jpg',
                  overview: 'Second',
                ),
              ],
              layout: const CinematicHeroLayout(
                kenBurns: false,
                compact: true,
              ),
              actionRowBuilder: actionRow,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.text('CTA a'), findsOneWidget);

    key.currentState!.stepFilm(1, instant: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(focus.hasFocus, isTrue, reason: 'carousel advance must not drop CTA focus');
    expect(find.text('CTA b'), findsOneWidget);
    expect(focus.context, isNotNull);
  });
}
