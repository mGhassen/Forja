import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/widgets/details/details_top_bar.dart';
import 'package:forja_foundation/widgets/details/episode_range_bar.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';
import 'package:forja_foundation/widgets/details/hero_title.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';
import 'package:forja_foundation/widgets/details/tv_season_episode_picker.dart';

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _wrap({required Size size, required Widget child, bool scroll = true}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: ShellPaintScope(
        useTvFocus: false,
        scaleOnHover: false,
        usesTvDensity: false,
        focusStyled: (context, {required focused}) => focused,
        child: Scaffold(
          body: scroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    ),
  );
}

DetailsHero _hero({bool? wideLayout, bool flowLayout = false}) {
  return DetailsHero(
    backdropUrl: '',
    title: 'Synthetic Title',
    genres: const ['Genre A', 'Genre B'],
    metaParts: const ['TV', '2026'],
    rating: 8.4,
    overview: 'A synthetic overview line for the layout test.',
    facts: const [MapEntry('Status', 'Released')],
    actionRow: const SizedBox(key: ValueKey('actions'), width: 120, height: 44),
    height: 330,
    wideLayout: wideLayout,
    flowLayout: flowLayout,
  );
}

TvSeasonEpisodePicker _picker({
  String episodeView = kEpisodeViewCards,
  bool listLayout = true,
  int seasonCount = 1,
  ValueChanged<int>? onSelected,
  ValueChanged<int>? onPlay,
}) {
  return TvSeasonEpisodePicker(
    tmdbId: 1,
    seasonCount: seasonCount,
    selectedSeason: 1,
    selectedEpisode: 1,
    isLoadingSeason: false,
    seasonData: {
      'episodes': [
        for (var i = 1; i <= 3; i++)
          {
            'episode_number': i,
            'name': 'Synthetic Episode $i',
            'overview': 'Overview $i',
            'runtime': 24,
            'still_path': '',
          },
      ],
    },
    watchedEpisodes: const {},
    fallbackPosterPath: '',
    onSeasonSelected: (_) {},
    onEpisodeSelected: onSelected ?? (_) {},
    onEpisodePlay: onPlay,
    onToggleWatched: (_, _) {},
    episodeView: episodeView,
    listLayout: listLayout,
  );
}

void main() {
  group('DetailsHero phone flow layout', () {
    testWidgets('landscape phone keeps genres, meta and overview', (
      tester,
    ) async {
      _setSurface(tester, const Size(914, 411));
      await tester.pumpWidget(
        _wrap(
          size: const Size(914, 411),
          child: _hero(wideLayout: false, flowLayout: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Genre A • Genre B'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
      expect(
        find.textContaining('synthetic overview', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('actions')), findsOneWidget);
      // Wide phone: facts sit beside the column, not over it.
      expect(find.byType(FactsPanel), findsOneWidget);
      final facts = tester.getTopLeft(find.byType(FactsPanel));
      final genres = tester.getTopRight(find.text('Genre A • Genre B'));
      expect(facts.dx, greaterThan(genres.dx));
    });

    testWidgets('hero grows to fit content beyond its min height', (
      tester,
    ) async {
      _setSurface(tester, const Size(914, 411));
      await tester.pumpWidget(
        _wrap(
          size: const Size(914, 411),
          child: _hero(wideLayout: false, flowLayout: true),
        ),
      );
      await tester.pumpAndSettle();
      final h = tester.getSize(find.byType(DetailsHero)).height;
      expect(h, greaterThanOrEqualTo(330));
      final actionsBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('actions')))
          .dy;
      expect(actionsBottom, lessThanOrEqualTo(h));
    });

    testWidgets('portrait phone is one column without the facts card', (
      tester,
    ) async {
      _setSurface(tester, const Size(411, 914));
      await tester.pumpWidget(
        _wrap(
          size: const Size(411, 914),
          child: _hero(wideLayout: false, flowLayout: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FactsPanel), findsNothing);
      expect(find.text('Genre A • Genre B'), findsOneWidget);
    });

    testWidgets('width default stays wide at the token breakpoint', (
      tester,
    ) async {
      _setSurface(tester, const Size(DetailsTokens.heroWideMinWidth, 700));
      await tester.pumpWidget(
        _wrap(
          size: const Size(DetailsTokens.heroWideMinWidth, 700),
          scroll: false,
          child: _hero(),
        ),
      );
      await tester.pumpAndSettle();
      // Wide hero overlays the facts card at the top end.
      expect(find.byType(FactsPanel), findsOneWidget);
    });
  });

  group('TvSeasonEpisodePicker phone list', () {
    testWidgets('cards view paints one vertical row per episode', (
      tester,
    ) async {
      _setSurface(tester, const Size(411, 914));
      await tester.pumpWidget(
        _wrap(size: const Size(411, 914), child: _picker()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final first = tester.getTopLeft(find.text('Synthetic Episode 1'));
      final second = tester.getTopLeft(find.text('Synthetic Episode 2'));
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, first.dx);
      // Inside the content gutter — never clipped at the left edge.
      final gutter = DetailsTokens.contentHorizontalPadding(411);
      expect(first.dx, greaterThan(gutter));
      expect(find.text('24m'), findsNWidgets(3));
    });

    testWidgets('row tap selects; thumbnail play plays', (tester) async {
      int? selected;
      int? played;
      _setSurface(tester, const Size(411, 914));
      await tester.pumpWidget(
        _wrap(
          size: const Size(411, 914),
          child: _picker(
            onSelected: (e) => selected = e,
            onPlay: (e) => played = e,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic Episode 2'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(played, isNull);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded).at(2));
      await tester.pumpAndSettle();
      expect(played, 3);
    });

    testWidgets('number chips toggle still works in list layout', (
      tester,
    ) async {
      _setSurface(tester, const Size(411, 914));
      await tester.pumpWidget(
        _wrap(
          size: const Size(411, 914),
          child: _picker(episodeView: kEpisodeViewChips),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Episode 1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('desktop picker keeps the horizontal cards', (tester) async {
      _setSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _wrap(size: const Size(1280, 800), child: _picker(listLayout: false)),
      );
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Synthetic Episode 1'));
      final second = tester.getTopLeft(find.text('Synthetic Episode 2'));
      // Same row (selected card lift shifts it by a few px).
      expect((second.dy - first.dy).abs(), lessThan(8));
      expect(second.dx, greaterThan(first.dx));
    });
  });

  group('DetailsCollapsingTopBar', () {
    Widget bar(double progress) => _wrap(
      size: const Size(411, 914),
      scroll: false,
      child: Stack(
        children: [
          DetailsCollapsingTopBar(
            progress: progress,
            title: 'Synthetic Title',
            backgroundColor: Colors.black,
            leading: const SizedBox(
              width: DetailsTokens.backHitSizeMobile,
              height: DetailsTokens.backHitSizeMobile,
            ),
          ),
        ],
      ),
    );

    double titleOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.text('Synthetic Title'),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('transparent over the hero, solid with title after', (
      tester,
    ) async {
      _setSurface(tester, const Size(411, 914));
      await tester.pumpWidget(bar(0));
      expect(titleOpacity(tester), 0);
      await tester.pumpWidget(bar(1));
      expect(titleOpacity(tester), 1);
      final h = tester.getSize(find.byType(ColoredBox).last).height;
      expect(h, DetailsTokens.topBarHeightMobile);
    });
  });

  testWidgets('DetailsStackedActions stretches the primary action', (
    tester,
  ) async {
    _setSurface(tester, const Size(411, 914));
    await tester.pumpWidget(
      _wrap(
        size: const Size(411, 914),
        scroll: false,
        child: const DetailsStackedActions(
          primary: SizedBox(key: ValueKey('primary'), height: 44),
          secondary: [
            SizedBox(key: ValueKey('secondary'), width: 80, height: 44),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('primary'))).width, 411);
    final primaryBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('primary')))
        .dy;
    final secondaryTop = tester
        .getTopLeft(find.byKey(const ValueKey('secondary')))
        .dy;
    expect(secondaryTop - primaryBottom, DetailsTokens.heroStackedActionGap);
  });

  testWidgets('HeroTitle paints a cached logo without the text title', (
    tester,
  ) async {
    const url = 'https://example.test/synthetic-logo.png';
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 4, 2),
        Paint()..color = Colors.white,
      );
      return recorder.endRecording().toImage(4, 2);
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
      const NetworkImage(url),
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image!)),
      ),
    );
    addTearDown(PaintingBinding.instance.imageCache.clear);

    _setSurface(tester, const Size(411, 914));

    await tester.pumpWidget(
      _wrap(
        size: const Size(411, 914),
        scroll: false,
        child: const HeroTitle(title: 'Synthetic Title', logoUrl: url),
      ),
    );
    await tester.pump();
    final textFade = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.textContaining('Synthetic Title', findRichText: true),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(textFade.opacity, 0);
  });
}
