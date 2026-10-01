import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:forja_foundation/widgets/catalog/rotating_hero_backdrop.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

Widget _paintScope({
  required Widget child,
  required bool scaleOnHover,
  required bool Function(BuildContext context, {required bool focused})
      focusStyled,
}) {
  return ShellPaintScope(
    useTvFocus: true,
    scaleOnHover: scaleOnHover,
    usesTvDensity: !scaleOnHover,
    focusStyled: focusStyled,
    child: child,
  );
}

void main() {
  testWidgets('hero keeps every slide backdrop mounted across carousel steps', (
    tester,
  ) async {
    final key = GlobalKey<CinematicHeroState>();
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
                CinematicHeroSlide(
                  id: 'c',
                  title: 'Gamma',
                  backdropUrl: 'https://example.com/c.jpg',
                  overview: 'Third',
                ),
              ],
              layout: const CinematicHeroLayout(
                kenBurns: false,
                compact: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RotatingHeroBackdrop), findsNWidgets(3));

    key.currentState!.stepFilm(1, instant: true);
    await tester.pump();
    expect(find.byType(RotatingHeroBackdrop), findsNWidgets(3));

    key.currentState!.stepFilm(1, instant: true);
    await tester.pump();
    expect(find.byType(RotatingHeroBackdrop), findsNWidgets(3));

    key.currentState!.stepFilm(-2, instant: true);
    await tester.pump();
    expect(find.byType(RotatingHeroBackdrop), findsNWidgets(3));
  });

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

  testWidgets('hero step indicator fills toward auto-advance', (tester) async {
    final key = GlobalKey<CinematicHeroState>();

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
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(key.currentState!.heroIndex, 0);
    expect(key.currentState!.heroAdvanceProgress, 0);

    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.5);
    expect(
      key.currentState!.heroAdvanceProgress,
      closeTo(0.5, 0.05),
    );
    expect(key.currentState!.heroIndex, 0);

    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.5);
    expect(key.currentState!.heroAdvanceProgress, closeTo(1.0, 0.01));

    // PageView needs stepped pumps — a single large duration pump may not settle.
    var advanced = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (key.currentState!.heroIndex == 1) {
        advanced = true;
        break;
      }
    }
    expect(advanced, isTrue, reason: 'auto-advance should move to the next slide');
    expect(key.currentState!.heroAdvanceProgress, lessThan(0.25));
  });

  testWidgets('manual stepFilm resets hero advance progress', (tester) async {
    final key = GlobalKey<CinematicHeroState>();

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
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.4);
    expect(key.currentState!.heroAdvanceProgress, greaterThan(0.2));

    key.currentState!.stepFilm(1, instant: true);
    await tester.pump();

    expect(key.currentState!.heroIndex, 1);
    expect(key.currentState!.heroAdvanceProgress, lessThan(0.05));
  });

  testWidgets('hero CTA focus pauses auto-advance until leave', (tester) async {
    final key = GlobalKey<CinematicHeroState>();
    final ctaFocus = FocusNode(debugLabel: 'hero-cta');
    addTearDown(ctaFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _paintScope(
            scaleOnHover: false,
            focusStyled: (_, {required focused}) => focused,
            child: SizedBox(
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
                actionRowBuilder: (context, slide, {required isActive}) {
                  if (!isActive) return const SizedBox.shrink();
                  return Focus(
                    focusNode: ctaFocus,
                    child: const Text('View details'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.25);
    final pausedAt = key.currentState!.heroAdvanceProgress;
    expect(pausedAt, greaterThan(0.1));

    ctaFocus.requestFocus();
    await tester.pump();
    expect(key.currentState!.heroAdvancePaused, isTrue);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(key.currentState!.heroAdvanceProgress, closeTo(pausedAt, 0.02));
    expect(key.currentState!.heroIndex, 0);

    ctaFocus.unfocus();
    await tester.pump();
    await tester.pump();
    expect(key.currentState!.heroAdvancePaused, isFalse);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);
    expect(
      key.currentState!.heroAdvanceProgress,
      greaterThan(pausedAt + 0.05),
    );
  });

  testWidgets(
    'desktop mouse-retained CTA focus does not hold pause after hover leave',
    (tester) async {
      final key = GlobalKey<CinematicHeroState>();
      final ctaFocus = FocusNode(debugLabel: 'hero-cta-desktop');
      addTearDown(ctaFocus.dispose);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(() {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _paintScope(
              scaleOnHover: true,
              focusStyled: (_, {required focused}) => false,
              child: SizedBox(
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
                  actionRowBuilder: (context, slide, {required isActive}) {
                    if (!isActive) return const SizedBox.shrink();
                    return Focus(
                      focusNode: ctaFocus,
                      child: const Text('View details'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('View details')));
      await tester.pump();
      ctaFocus.requestFocus();
      await tester.pump();
      expect(key.currentState!.heroAdvancePaused, isTrue);
      expect(ctaFocus.hasFocus, isTrue);

      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(
        key.currentState!.heroAdvancePaused,
        isFalse,
        reason: 'invisible mouse focus must not freeze auto-advance',
      );
      expect(ctaFocus.hasFocus, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      final resumed = key.currentState!.heroAdvanceProgress;
      await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);
      expect(key.currentState!.heroAdvanceProgress, greaterThan(resumed));
    },
  );

  testWidgets('hero CTA hover clears when action row remounts', (tester) async {
    final key = GlobalKey<CinematicHeroState>();

    Widget buildHero() {
      return MaterialApp(
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
              actionRowBuilder: (context, slide, {required isActive}) {
                if (!isActive) return const SizedBox.shrink();
                return const Text('View details');
              },
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHero());
    await tester.pump();
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('View details')));
    await tester.pump();
    expect(key.currentState!.heroAdvancePaused, isTrue);

    // Leave before remount so the new MouseRegion does not auto-reenter.
    await gesture.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(key.currentState!.heroAdvancePaused, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(buildHero());
    await tester.pump();

    expect(key.currentState!.heroAdvancePaused, isFalse);
    final moving = key.currentState!.heroAdvanceProgress;
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);
    expect(key.currentState!.heroAdvanceProgress, greaterThan(moving));
  });

  testWidgets('hero CTA hover pauses auto-advance', (tester) async {
    final key = GlobalKey<CinematicHeroState>();

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
              actionRowBuilder: (context, slide, {required isActive}) {
                if (!isActive) return const SizedBox.shrink();
                return const Text('View details');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('View details')));
    await tester.pump();

    expect(key.currentState!.heroAdvancePaused, isTrue);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    final pausedAt = key.currentState!.heroAdvanceProgress;
    await tester.pump(const Duration(seconds: 3));
    expect(key.currentState!.heroAdvanceProgress, closeTo(pausedAt, 0.02));

    await gesture.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(key.currentState!.heroAdvancePaused, isFalse);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    final resumed = key.currentState!.heroAdvanceProgress;
    await tester.pump(ShellTokens.heroAutoAdvanceDuration * 0.2);
    expect(key.currentState!.heroAdvanceProgress, greaterThan(resumed));
  });
}
