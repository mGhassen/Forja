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
}
