import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/card_quick_menu.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/catalog/rotating_hero_backdrop.dart';
import 'package:forja_foundation/widgets/catalog/shell_mood_circle.dart';
import 'package:forja_foundation/widgets/chrome/pointer_down_claim.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';

const _phonePortrait = Size(411, 914);
const _phoneLandscape = Size(914, 411);

Widget _scope({
  required Widget child,
  Size size = _phonePortrait,
  bool mobile = true,
  bool tv = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: ShellPaintScope(
        useTvFocus: tv,
        scaleOnHover: !mobile && !tv,
        usesTvDensity: tv,
        usesMobileDensity: mobile,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// Cards fully or partly visible after the rail leading pad.
double _cardsAcross(Size viewport, double cardW) =>
    (viewport.width - ShellTokens.homeSectionHorizontalPadding) /
    (cardW + ShellTokens.posterCardRowGapMobile);

const _slides = [
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
    portraitImageUrl: 'https://example.com/b-vertical.jpg',
    overview: 'Second',
  ),
  CinematicHeroSlide(
    id: 'c',
    title: 'Gamma',
    backdropUrl: 'https://example.com/c.jpg',
    portraitImageAlignment: Alignment.centerLeft,
    overview: 'Third',
  ),
];

Widget _hero(
  GlobalKey<CinematicHeroState> key, {
  required bool mobile,
  double? maxImageHeight,
}) {
  return SingleChildScrollView(
    child: CinematicHero(
      key: key,
      slides: _slides,
      layout: CinematicHeroLayout(
        kenBurns: false,
        compact: true,
        mobile: mobile,
        maxImageHeight: maxImageHeight,
      ),
    ),
  );
}

RotatingHeroBackdrop _backdropFor(WidgetTester tester, String id) =>
    tester.widget<RotatingHeroBackdrop>(
      find.byKey(ValueKey('hero-bg-$id'), skipOffstage: false),
    );

void main() {
  group('touch poster width', () {
    test('portrait phone shows about three cards plus a peek', () {
      final w = ShellTokens.posterCardWidthMobileFor(_phonePortrait);
      expect(w, lessThan(ShellTokens.posterCardWidthMobile));
      final across = _cardsAcross(_phonePortrait, w);
      expect(across, greaterThanOrEqualTo(3.1));
      expect(across, lessThan(3.6));
    });

    test('landscape phone shows five to six cards', () {
      final w = ShellTokens.posterCardWidthMobileFor(_phoneLandscape);
      final across = _cardsAcross(_phoneLandscape, w);
      expect(across, greaterThanOrEqualTo(5));
      expect(across, lessThanOrEqualTo(6.2));
      // Title row + one card row fit above a bottom bar on a 411 dp screen.
      final cardH = w * ShellTokens.posterCardAspectRatio;
      expect(cardH, lessThan(411 - ShellTokens.bottomNavHeight - 60));
    });

    test('tablets keep the pre-existing touch ceiling', () {
      expect(
        ShellTokens.posterCardWidthMobileFor(const Size(800, 1280)),
        ShellTokens.posterCardWidthDesktop,
      );
      expect(
        ShellTokens.posterCardWidthMobileFor(const Size(1280, 800)),
        ShellTokens.posterCardWidthDesktop,
      );
    });

    testWidgets('InteractivePosterCard uses it only under mobile density', (
      tester,
    ) async {
      late double mobileW;
      late double desktopW;
      late double tvW;
      await tester.pumpWidget(
        _scope(
          size: _phoneLandscape,
          child: Builder(
            builder: (context) {
              mobileW = InteractivePosterCard.cardWidth(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _scope(
          size: _phoneLandscape,
          mobile: false,
          child: Builder(
            builder: (context) {
              desktopW = InteractivePosterCard.cardWidth(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _scope(
          size: const Size(1920, 1080),
          mobile: false,
          tv: true,
          child: Builder(
            builder: (context) {
              tvW = InteractivePosterCard.cardWidth(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(mobileW, ShellTokens.posterCardWidthMobileFor(_phoneLandscape));
      expect(desktopW, ShellTokens.posterCardWidthDesktop);
      expect(tvW, ShellTokens.posterCardWidthTv);
    });
  });

  group('touch cinematic hero', () {
    testWidgets('dots run horizontally under the actions on touch', (
      tester,
    ) async {
      final key = GlobalKey<CinematicHeroState>();
      await tester.pumpWidget(_scope(child: _hero(key, mobile: true)));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('cinematic-hero-step-dots-horizontal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cinematic-hero-step-dots-vertical')),
        findsNothing,
      );
    });

    testWidgets('rotation on a 2.625 dpr phone lays the pages out cleanly', (
      tester,
    ) async {
      // 1080 px / 2.625 = 411.428… dp: the page width is not exact in binary.
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final key = GlobalKey<CinematicHeroState>();
      for (final physical in const [Size(2400, 1080), Size(1080, 2400)]) {
        tester.view.physicalSize = physical;
        final logical = physical / 2.625;
        await tester.pumpWidget(
          _scope(size: logical, child: _hero(key, mobile: true)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('non-touch keeps the vertical right-edge dots', (tester) async {
      final key = GlobalKey<CinematicHeroState>();
      await tester.pumpWidget(
        _scope(mobile: false, child: _hero(key, mobile: false)),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('cinematic-hero-step-dots-vertical')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cinematic-hero-step-dots-horizontal')),
        findsNothing,
      );
    });

    testWidgets('portrait crop: vertical art, focal hint, centered default', (
      tester,
    ) async {
      final key = GlobalKey<CinematicHeroState>();
      await tester.pumpWidget(_scope(child: _hero(key, mobile: true)));
      await tester.pump();
      expect(
        _backdropFor(tester, 'a').imageAlignment,
        ShellTokens.heroBackdropAlignmentPortrait,
      );
      expect(_backdropFor(tester, 'b').imageUrls, [
        'https://example.com/b-vertical.jpg',
      ]);
      expect(_backdropFor(tester, 'c').imageAlignment, Alignment.centerLeft);
    });

    testWidgets('landscape and non-touch keep the wide backdrop crop', (
      tester,
    ) async {
      final key = GlobalKey<CinematicHeroState>();
      await tester.pumpWidget(
        _scope(size: _phoneLandscape, child: _hero(key, mobile: true)),
      );
      await tester.pump();
      expect(_backdropFor(tester, 'b').imageUrls, [
        'https://example.com/b.jpg',
      ]);
      expect(_backdropFor(tester, 'a').imageAlignment, Alignment.centerRight);

      await tester.pumpWidget(
        _scope(mobile: false, child: _hero(key, mobile: false)),
      );
      await tester.pump();
      expect(_backdropFor(tester, 'b').imageUrls, [
        'https://example.com/b.jpg',
      ]);
      expect(_backdropFor(tester, 'a').imageAlignment, Alignment.centerRight);
    });

    Future<List<({double dx, double opacity})>> midSwipeLayers(
      WidgetTester tester, {
      required bool mobile,
    }) async {
      final key = GlobalKey<CinematicHeroState>();
      await tester.pumpWidget(
        _scope(
          mobile: mobile,
          child: _hero(key, mobile: mobile),
        ),
      );
      await tester.pump();
      final c = key.currentState!.pageController;
      c.jumpTo(c.position.pixels + c.position.viewportDimension * 0.5);
      await tester.pump();
      final out = <({double dx, double opacity})>[];
      for (var i = 0; i < _slides.length; i++) {
        final layer = find.byKey(
          ValueKey('hero-layer-$i'),
          skipOffstage: false,
        );
        final t = tester.widget<Transform>(layer);
        final o = tester.widget<Opacity>(
          find
              .descendant(
                of: layer,
                matching: find.byType(Opacity, skipOffstage: false),
                skipOffstage: false,
              )
              .first,
        );
        final off = tester.widget<Offstage>(
          find
              .descendant(
                of: layer,
                matching: find.byType(Offstage, skipOffstage: false),
                skipOffstage: false,
              )
              .first,
        );
        if (off.offstage) continue;
        out.add((dx: t.transform.getTranslation().x, opacity: o.opacity));
      }
      return out;
    }

    testWidgets('touch swipe crossfades stills in place (no seam)', (
      tester,
    ) async {
      final layers = await midSwipeLayers(tester, mobile: true);
      expect(layers.length, 2);
      for (final l in layers) {
        expect(l.dx, 0);
      }
      final opacities = layers.map((l) => l.opacity).toList()..sort();
      expect(opacities.last, 1.0);
      expect(opacities.first, closeTo(0.5, 0.01));
    });

    testWidgets('non-touch swipe still slides the stills', (tester) async {
      final layers = await midSwipeLayers(tester, mobile: false);
      expect(layers.length, 2);
      expect(layers.any((l) => l.dx.abs() > 1), isTrue);
      for (final l in layers) {
        expect(l.opacity, 1.0);
      }
    });

    testWidgets('maxImageHeight caps the band', (tester) async {
      final key = GlobalKey<CinematicHeroState>();
      await tester.pumpWidget(
        _scope(
          size: _phoneLandscape,
          child: _hero(key, mobile: true, maxImageHeight: 200),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(CinematicHero)).height, 200);
      expect(tester.takeException(), isNull);
    });
  });

  group('touch mood circles', () {
    Future<Text> label(WidgetTester tester, {required bool mobile}) async {
      await tester.pumpWidget(
        _scope(
          mobile: mobile,
          child: Center(
            child: ShellMoodCircleItem(
              layout: MoodCircleLayout.desktop,
              label: 'Mind-Bending Thrillers',
              icon: Icons.psychology_rounded,
              accent: const Color(0xFF475569),
              selected: true,
              onTap: () {},
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.text('Mind-Bending Thrillers'));
    }

    testWidgets('selected label is bold primary and single-line on touch', (
      tester,
    ) async {
      final t = await label(tester, mobile: true);
      expect(t.maxLines, 1);
      expect(t.overflow, TextOverflow.ellipsis);
      expect(t.style!.color, ForjaShellColors.textPrimary);
      expect(t.style!.fontWeight, FontWeight.w800);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop keeps the accent label and two lines', (tester) async {
      final t = await label(tester, mobile: false);
      expect(t.maxLines, ShellTokens.moodCircleLabelMaxLines);
      expect(t.style!.color, const Color(0xFF475569));
    });

    test('resolve picks the touch layout only under mobile density', () {
      expect(MoodCircleLayout.mobile.labelMaxLines, 1);
      expect(MoodCircleLayout.mobile.selectedRing, isTrue);
      expect(MoodCircleLayout.desktop.selectedRing, isFalse);
      expect(MoodCircleLayout.tvScrollable.selectedRing, isFalse);
    });
  });

  group('touch card pin + quick sheet', () {
    Widget pin() => ListStatusPin(
      currentStatus: null,
      onSelect: (_) async {},
      excludeFromTvTraversal: true,
    );

    testWidgets('card "+" hit area is at least 48 dp on touch', (tester) async {
      await tester.pumpWidget(_scope(child: Align(child: pin())));
      final size = tester.getSize(find.byType(PointerDownClaim));
      expect(size.width, greaterThanOrEqualTo(ShellTokens.touchMinHitSize));
      expect(size.height, greaterThanOrEqualTo(ShellTokens.touchMinHitSize));
    });

    testWidgets('desktop card pin stays icon-sized', (tester) async {
      await tester.pumpWidget(
        _scope(mobile: false, child: Align(child: pin())),
      );
      final size = tester.getSize(find.byType(PointerDownClaim));
      expect(size.width, lessThan(ShellTokens.touchMinHitSize));
    });

    testWidgets('quick sheet rows are touch-height and fire their action', (
      tester,
    ) async {
      final fired = <String>[];
      await tester.pumpWidget(
        _scope(
          child: CardQuickActionSheet(
            title: 'Synthetic',
            actions: [
              CardQuickMenuAction(
                id: 'play',
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                onTap: () => fired.add('play'),
              ),
              CardQuickMenuAction(
                id: 'details',
                label: 'Details',
                icon: Icons.info_outline_rounded,
                onTap: () => fired.add('details'),
              ),
            ],
          ),
        ),
      );
      final row = find.byKey(const ValueKey('card-quick-sheet-details'));
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(ShellTokens.touchMinHitSize),
      );
      await tester.tap(row);
      expect(fired, ['details']);
    });
  });
}
