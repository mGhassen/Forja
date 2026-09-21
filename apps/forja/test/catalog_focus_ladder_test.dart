import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

/// Synthetic catalog tab — proves paint-order ladder, not a shipped hub id.
const _tab = 'catalog';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: FocusScope(
          child: TvFocusGraph(tabId: _tab, child: child),
        ),
      ),
    ),
  );
}

FocusableControl _item({
  required FocusNode node,
  required String rowId,
  required int index,
}) {
  return FocusableControl(
    focusNode: node,
    tvMeta: ShellTvFocusMeta(
      tabId: _tab,
      zone: ShellTvZone.row,
      rowId: rowId,
      itemIndex: index,
    ),
    onTap: () {},
    child: const SizedBox(width: 40, height: 40),
  );
}

void main() {
  setUp(() {
    ShellTvFocusCoordinator.setNavOrder([_tab]);
    ShellTvFocus.currentNavTabId = _tab;
    ShellTvFocusCoordinator.clearTab(_tab);
    PackPaintArtifact.clearStableSortOrdersForTest();
  });

  test('stableSortOrder follows first-seen paint order', () {
    final popular = PackPaintArtifact.stableSortOrder(_tab, 'popular');
    final continueRow =
        PackPaintArtifact.stableSortOrder(_tab, 'continue_watching');
    final moodChips = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');
    final moodResults =
        PackPaintArtifact.stableSortOrder(_tab, 'mood-results');
    final shuffle =
        PackPaintArtifact.stableSortOrder(_tab, 'because-shuffle');
    final because = PackPaintArtifact.stableSortOrder(_tab, 'because');

    expect(popular, lessThan(continueRow));
    expect(continueRow, lessThan(moodChips));
    expect(moodChips, lessThan(moodResults));
    expect(moodResults, lessThan(shuffle));
    expect(shuffle, lessThan(because));
    // Stable across rebuilds.
    expect(
      PackPaintArtifact.stableSortOrder(_tab, 'popular'),
      popular,
    );
  });

  test('reserveHubFocusRowOrder locks layout order before late bleed paint', () {
    // Simulate wrong first-seen order (mood before featured) then correct.
    PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');
    PackPaintArtifact.stableSortOrder(_tab, 'mood-results');
    PackPaintArtifact.stableSortOrder(_tab, 'featured');
    PackPaintArtifact.stableSortOrder(_tab, 'popular');

    PackPaintArtifact.reserveHubFocusRowOrder(_tab, const [
      'featured',
      'popular',
      'continue_watching',
      'mood-chips',
      'mood-results',
      'because-shuffle',
      'because',
      'new_releases',
      'genre_animation',
    ]);

    final featured = PackPaintArtifact.stableSortOrder(_tab, 'featured');
    final popular = PackPaintArtifact.stableSortOrder(_tab, 'popular');
    final continueRow =
        PackPaintArtifact.stableSortOrder(_tab, 'continue_watching');
    final mood = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');
    final genre = PackPaintArtifact.stableSortOrder(_tab, 'genre_animation');

    expect(featured, lessThan(popular));
    expect(popular, lessThan(continueRow));
    expect(continueRow, lessThan(mood));
    expect(mood, lessThan(genre));
  });

  testWidgets(
    '↓ walk popular → continue → mood-chips → mood-results → shuffle → because',
    (tester) async {
      final popular = FocusNode(debugLabel: 'popular');
      final continueNode = FocusNode(debugLabel: 'continue');
      final moodChip = FocusNode(debugLabel: 'mood-chip');
      final moodResult = FocusNode(debugLabel: 'mood-result');
      final shuffle = FocusNode(debugLabel: 'shuffle');
      final because = FocusNode(debugLabel: 'because');

      final sPopular = PackPaintArtifact.stableSortOrder(_tab, 'popular');
      final sContinue =
          PackPaintArtifact.stableSortOrder(_tab, 'continue_watching');
      final sChips = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');
      final sResults =
          PackPaintArtifact.stableSortOrder(_tab, 'mood-results');
      final sShuffle =
          PackPaintArtifact.stableSortOrder(_tab, 'because-shuffle');
      final sBecause = PackPaintArtifact.stableSortOrder(_tab, 'because');

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvKitRow(
                rowId: 'popular',
                sortOrder: sPopular,
                itemCount: 1,
                child: _item(node: popular, rowId: 'popular', index: 0),
              ),
              TvKitRow(
                rowId: 'continue_watching',
                sortOrder: sContinue,
                itemCount: 1,
                child: _item(
                  node: continueNode,
                  rowId: 'continue_watching',
                  index: 0,
                ),
              ),
              TvKitRow(
                rowId: 'mood-chips',
                sortOrder: sChips,
                itemCount: 1,
                child: _item(node: moodChip, rowId: 'mood-chips', index: 0),
              ),
              TvKitRow(
                rowId: 'mood-results',
                sortOrder: sResults,
                itemCount: 1,
                child:
                    _item(node: moodResult, rowId: 'mood-results', index: 0),
              ),
              TvKitRow(
                rowId: 'because-shuffle',
                sortOrder: sShuffle,
                itemCount: 1,
                child: _item(node: shuffle, rowId: 'because-shuffle', index: 0),
              ),
              TvKitRow(
                rowId: 'because',
                sortOrder: sBecause,
                itemCount: 1,
                child: _item(node: because, rowId: 'because', index: 0),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      popular.requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'popular',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(continueNode.hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'continue_watching',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(moodChip.hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'mood-chips',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(moodResult.hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'mood-results',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(shuffle.hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'because-shuffle',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(because.hasFocus, isTrue);

      // ↑ walks back toward popular (not a dead spotlight edge).
      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'continue_watching',
          currentIndex: 0,
          down: false,
        ),
        isTrue,
      );
      await tester.pump();
      expect(popular.hasFocus, isTrue);

      for (final n in [
        popular,
        continueNode,
        moodChip,
        moodResult,
        shuffle,
        because,
      ]) {
        n.dispose();
      }
    },
  );

  testWidgets('↓ from popular skips missing continue to mood-chips',
      (tester) async {
    final popular = FocusNode(debugLabel: 'popular');
    final moodChip = FocusNode(debugLabel: 'mood-chip');

    final sPopular = PackPaintArtifact.stableSortOrder(_tab, 'popular');
    // Reserve continue slot without registering a row (empty continue).
    PackPaintArtifact.stableSortOrder(_tab, 'continue_watching');
    final sChips = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');

    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            TvKitRow(
              rowId: 'popular',
              sortOrder: sPopular,
              itemCount: 1,
              child: _item(node: popular, rowId: 'popular', index: 0),
            ),
            TvKitRow(
              rowId: 'mood-chips',
              sortOrder: sChips,
              itemCount: 1,
              child: _item(node: moodChip, rowId: 'mood-chips', index: 0),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    popular.requestFocus();
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.moveVerticalInTab(
        tabId: _tab,
        rowId: 'popular',
        currentIndex: 0,
        down: true,
      ),
      isTrue,
    );
    await tester.pump();
    expect(moodChip.hasFocus, isTrue);

    popular.dispose();
    moodChip.dispose();
  });

  testWidgets(
    '↓ pack focusDown miss (empty continue) walks to mood-chips',
    (tester) async {
      final popular = FocusNode(debugLabel: 'popular');
      final moodChip = FocusNode(debugLabel: 'mood-chip');
      final sPopular = PackPaintArtifact.stableSortOrder(_tab, 'popular');
      final sChips = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');

      addTearDown(() {
        popular.dispose();
        moodChip.dispose();
      });

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvKitRow(
                rowId: 'popular',
                sortOrder: sPopular,
                itemCount: 1,
                onFocusDown: () {
                  ShellTvFocusCoordinator.beginKitEdgeAttempt();
                  ShellTvFocusCoordinator.markKitEdgeMiss();
                },
                child: _item(node: popular, rowId: 'popular', index: 0),
              ),
              TvKitRow(
                rowId: 'mood-chips',
                sortOrder: sChips,
                itemCount: 1,
                child: _item(node: moodChip, rowId: 'mood-chips', index: 0),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      popular.requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'popular',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(moodChip.hasFocus, isTrue);
    },
  );

  testWidgets(
    '↓ pack focusDown miss (empty because) walks to new_releases',
    (tester) async {
      final moodChip = FocusNode(debugLabel: 'mood-chip');
      final newReleases = FocusNode(debugLabel: 'new_releases');
      final sChips = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');
      PackPaintArtifact.stableSortOrder(_tab, 'because-shuffle');
      PackPaintArtifact.stableSortOrder(_tab, 'because');
      final sNew = PackPaintArtifact.stableSortOrder(_tab, 'new_releases');

      addTearDown(() {
        moodChip.dispose();
        newReleases.dispose();
      });

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvKitRow(
                rowId: 'mood-chips',
                sortOrder: sChips,
                itemCount: 1,
                onFocusDown: () {
                  ShellTvFocusCoordinator.beginKitEdgeAttempt();
                  // Pack focusDown: because-shuffle — unmounted / empty.
                  ShellTvFocusCoordinator.markKitEdgeMiss();
                },
                child: _item(node: moodChip, rowId: 'mood-chips', index: 0),
              ),
              TvKitRow(
                rowId: 'new_releases',
                sortOrder: sNew,
                itemCount: 1,
                child: _item(node: newReleases, rowId: 'new_releases', index: 0),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      moodChip.requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'mood-chips',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(newReleases.hasFocus, isTrue);
    },
  );

  testWidgets(
    '↓ from last registered row nudges page scroll then lands on new neighbor',
    (tester) async {
      final popular = FocusNode(debugLabel: 'popular');
      final moodChip = FocusNode(debugLabel: 'mood-chip');
      final sPopular = PackPaintArtifact.stableSortOrder(_tab, 'popular');
      final sChips = PackPaintArtifact.stableSortOrder(_tab, 'mood-chips');
      var nudged = false;

      addTearDown(() {
        popular.dispose();
        moodChip.dispose();
        ShellTvFocusCoordinator.setTabPageScroll(_tab, null);
      });

      // Mood tile is mounted (has FocusNode context) but its TvKitRow is not
      // registered yet — same as a below-fold Home section outside cacheExtent.
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvKitRow(
                rowId: 'popular',
                sortOrder: sPopular,
                itemCount: 1,
                child: _item(node: popular, rowId: 'popular', index: 0),
              ),
              _item(node: moodChip, rowId: 'mood-chips', index: 0),
            ],
          ),
        ),
      );
      await tester.pump();
      popular.requestFocus();
      await tester.pump();

      ShellTvFocusCoordinator.setTabPageScroll(_tab, ({required bool down}) {
        expect(down, isTrue);
        nudged = true;
        ShellTvFocusCoordinator.registerRow(
          ShellTvRowHandle(
            tabId: _tab,
            rowId: 'mood-chips',
            sortOrder: sChips,
            itemCount: 1,
            nodeAt: (i) => i == 0 ? moodChip : null,
          ),
        );
        return true;
      });

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'popular',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      expect(nudged, isTrue);
      await tester.pump();
      await tester.pump();
      expect(moodChip.hasFocus, isTrue);
    },
  );

  testWidgets(
    '↓ walks search filter strips with distinct sortOrders (genre→country→language)',
    (tester) async {
      final genre = FocusNode(debugLabel: 'genre');
      final country = FocusNode(debugLabel: 'country');
      final language = FocusNode(debugLabel: 'language');

      // Same numbers CatalogSearchFilterLens assigns — shared 4 would skip.
      const genreSort = 4;
      const countrySort = 5;
      const languageSort = 6;

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TvKitRow(
                rowId: 'search_filter_genre',
                sortOrder: genreSort,
                itemCount: 1,
                child: _item(
                  node: genre,
                  rowId: 'search_filter_genre',
                  index: 0,
                ),
              ),
              TvKitRow(
                rowId: 'search_filter_country',
                sortOrder: countrySort,
                itemCount: 1,
                child: _item(
                  node: country,
                  rowId: 'search_filter_country',
                  index: 0,
                ),
              ),
              TvKitRow(
                rowId: 'search_filter_language',
                sortOrder: languageSort,
                itemCount: 1,
                child: _item(
                  node: language,
                  rowId: 'search_filter_language',
                  index: 0,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      genre.requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'search_filter_genre',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(country.hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'search_filter_country',
          currentIndex: 0,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(language.hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: _tab,
          rowId: 'search_filter_language',
          currentIndex: 0,
          down: false,
        ),
        isTrue,
      );
      await tester.pump();
      expect(country.hasFocus, isTrue);

      genre.dispose();
      country.dispose();
      language.dispose();
    },
  );
}
