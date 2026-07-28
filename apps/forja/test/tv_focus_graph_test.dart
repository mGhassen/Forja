import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: FocusScope(
          child: TvFocusGraph(tabId: 'home', child: child),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    ShellTvFocusCoordinator.setNavOrder(['home', 'search']);
    ShellTvFocus.currentNavTabId = 'home';
    ShellTvFocusCoordinator.clearTab('home');
  });

  testWidgets('TvCatalogRow registers and unregisters with the coordinator',
      (tester) async {
    final node0 = FocusNode(debugLabel: 'item-0');
    final node1 = FocusNode(debugLabel: 'item-1');

    await tester.pumpWidget(
      _wrapTv(
        TvCatalogRow(
          rowId: 'featured',
          sortOrder: 0,
          itemCount: 2,
          child: Row(
            children: [
              FocusableControl(
                focusNode: node0,
                tvMeta: const ShellTvFocusMeta(
                  tabId: 'home',
                  zone: ShellTvZone.row,
                  rowId: 'featured',
                  itemIndex: 0,
                ),
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
              FocusableControl(
                focusNode: node1,
                tvMeta: const ShellTvFocusMeta(
                  tabId: 'home',
                  zone: ShellTvZone.row,
                  rowId: 'featured',
                  itemIndex: 1,
                ),
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.rowHandle('home', 'featured'),
      isNotNull,
    );
    expect(
      ShellTvFocusCoordinator.rowHandle('home', 'featured')!.itemCount,
      2,
    );

    await tester.pumpWidget(_wrapTv(const SizedBox.shrink()));
    await tester.pump();

    expect(ShellTvFocusCoordinator.rowHandle('home', 'featured'), isNull);

    node0.dispose();
    node1.dispose();
  });

  testWidgets('TvChipStrip down moves to results row', (tester) async {
    final chip0 = FocusNode(debugLabel: 'chip-0');
    final result0 = FocusNode(debugLabel: 'result-0');

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            TvChipStrip(
              rowId: 'mood-chips',
              sortOrder: 3,
              itemCount: 1,
              resultsRowId: 'mood-results',
              builder: (context, edgesFor) {
                final edges = edgesFor(0);
                return FocusableControl(
                  focusNode: chip0,
                  tvMeta: const ShellTvFocusMeta(
                    tabId: 'home',
                    zone: ShellTvZone.chipStrip,
                    rowId: 'mood-chips',
                    itemIndex: 0,
                  ),
                  onTap: edges.onSelectAlreadySelected,
                  onDownEdge: edges.onDown,
                  child: const SizedBox(width: 40, height: 40),
                );
              },
            ),
            TvCatalogRow(
              rowId: 'mood-results',
              sortOrder: 4,
              itemCount: 1,
              child: FocusableControl(
                focusNode: result0,
                tvMeta: const ShellTvFocusMeta(
                  tabId: 'home',
                  zone: ShellTvZone.row,
                  rowId: 'mood-results',
                  itemIndex: 0,
                ),
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    chip0.requestFocus();
    await tester.pump();
    expect(chip0.hasFocus, isTrue);

    expect(
      ShellTvFocusCoordinator.focusFromChipStripDown(
        tabId: 'home',
        chipRowId: 'mood-chips',
        resultsRowId: 'mood-results',
      ),
      isTrue,
    );
    await tester.pump();
    expect(result0.hasFocus, isTrue);

    chip0.dispose();
    result0.dispose();
  });

  testWidgets('TvHeroActions.bind registers tab defaults', (tester) async {
    final play = FocusNode(debugLabel: 'hero-play');
    var revealed = false;

    TvHeroActions.bind(
      'home',
      defaultFocus: () => play,
      heroReveal: () => revealed = true,
    );

    await tester.pumpWidget(
      _wrapTv(Focus(focusNode: play, child: const SizedBox(width: 40, height: 40))),
    );
    await tester.pump();

    expect(ShellTvFocusCoordinator.focusHero(tabId: 'home'), isTrue);
    await tester.pump();
    expect(play.hasFocus, isTrue);
    expect(revealed, isTrue);

    TvHeroActions.unbind('home');
    play.dispose();
  });

  testWidgets('left edge from first catalog item focuses nav', (tester) async {
    final nav = FocusNode(debugLabel: 'nav-home');
    final item = FocusNode(debugLabel: 'card-0');
    ShellTvFocus.registerNav('home', nav);

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            Focus(focusNode: nav, child: const SizedBox(width: 40, height: 40)),
            TvCatalogRow(
              rowId: 'popular',
              sortOrder: 1,
              itemCount: 1,
              child: FocusableControl(
                focusNode: item,
                tvMeta: const ShellTvFocusMeta(
                  tabId: 'home',
                  zone: ShellTvZone.row,
                  rowId: 'popular',
                  itemIndex: 0,
                ),
                onLeftEdge: () {
                  ShellTvFocusCoordinator.focusActiveNavTab();
                },
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    item.requestFocus();
    await tester.pump();
    expect(
      ShellTvFocusCoordinator.focusActiveNavTab(),
      isTrue,
    );
    await tester.pump();
    expect(nav.hasFocus, isTrue);

    item.dispose();
    nav.dispose();
  });

  testWidgets('TvGrid registers and exposes scope meta', (tester) async {
    final node = FocusNode(debugLabel: 'grid-0');

    await tester.pumpWidget(
      _wrapTv(
        TvFocusGraph(
          tabId: 'search',
          child: TvGrid(
            rowId: 'results',
            sortOrder: 1,
            columns: 4,
            itemCount: 1,
            child: Builder(
              builder: (context) {
                final scope = TvGridScope.maybeOf(context);
                expect(scope, isNotNull);
                expect(scope!.columns, 4);
                final meta = scope.metaFor(0);
                return FocusableControl(
                  focusNode: node,
                  tvMeta: ShellTvFocusMeta(
                    tabId: meta.tvTabId,
                    zone: meta.tvZone,
                    rowId: meta.tvRowId,
                    itemIndex: meta.tvItemIndex,
                    gridColumns: meta.gridColumns,
                  ),
                  onTap: () {},
                  child: const SizedBox(width: 40, height: 40),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.rowHandle('search', 'results'),
      isNotNull,
    );
    expect(
      ShellTvFocusCoordinator.rowHandle('search', 'results')!.itemCount,
      1,
    );

    node.dispose();
  });

  testWidgets('TvOverlayScope wraps child under TV policy', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      _wrapTv(
        TvOverlayScope(
          onDismiss: () => dismissed = true,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FocusScope), findsWidgets);
    expect(ShellTvLinearFocusScope.activeOf(
      tester.element(find.byType(SizedBox).first),
    ), isTrue);
    expect(dismissed, isFalse);
  });
}
