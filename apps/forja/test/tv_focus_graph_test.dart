import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('TvOverlayScope wraps child under TV policy (spatial default)',
      (tester) async {
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
    final boxCtx = tester.element(find.byType(SizedBox).first);
    expect(ShellTvLinearFocusScope.activeOf(boxCtx), isFalse);
    expect(ShellTvContainDpad.activeOf(boxCtx), isTrue);
    expect(dismissed, isFalse);
  });

  testWidgets('TvOverlayScope linear:true still marks linear host', (tester) async {
    await tester.pumpWidget(
      _wrapTv(
        const TvOverlayScope(
          linear: true,
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );
    await tester.pump();
    expect(
      ShellTvLinearFocusScope.activeOf(
        tester.element(find.byType(SizedBox).first),
      ),
      isTrue,
    );
  });

  testWidgets(
    'allowNestedFocus: parent onRightEdge can focus nested control',
    (tester) async {
      final parent = FocusNode(debugLabel: 'parent');
      final child = FocusNode(debugLabel: 'child');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: FocusableControl(
                    focusNode: parent,
                    autoFocus: true,
                    allowNestedFocus: true,
                    scaleOnFocus: 1.0,
                    onTap: () {},
                    onRightEdge: () => child.requestFocus(),
                    child: FocusableControl(
                      focusNode: child,
                      scaleOnFocus: 1.0,
                      onTap: () {},
                      child: const SizedBox(width: 80, height: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(parent.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(child.hasFocus, isTrue);

      parent.dispose();
      child.dispose();
    },
  );

  testWidgets(
    'TvOverlayScope spatial: ↓ from top-left reaches bottom-left (not reading next)',
    (tester) async {
      final topLeft = FocusNode(debugLabel: 'tl');
      final topRight = FocusNode(debugLabel: 'tr');
      final bottomLeft = FocusNode(debugLabel: 'bl');
      final bottomRight = FocusNode(debugLabel: 'br');

      Widget cell(FocusNode node, {bool autoFocus = false}) {
        return FocusableControl(
          focusNode: node,
          autoFocus: autoFocus,
          scaleOnFocus: 1.0,
          onTap: () {},
          child: const SizedBox(width: 80, height: 80),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: TvOverlayScope(
                    autofocusFirst: false,
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              cell(topLeft, autoFocus: true),
                              cell(topRight),
                            ],
                          ),
                          Row(
                            children: [
                              cell(bottomLeft),
                              cell(bottomRight),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(topLeft.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        bottomLeft.hasFocus,
        isTrue,
        reason: 'spatial ↓ must land below, not on reading-order next (topRight)',
      );
      expect(topRight.hasFocus, isFalse);

      topLeft.dispose();
      topRight.dispose();
      bottomLeft.dispose();
      bottomRight.dispose();
    },
  );

  testWidgets(
    'settings-zone tvMeta: ↓ still moves focus (not blocked by zone-only meta)',
    (tester) async {
      final top = FocusNode(debugLabel: 'settings-top');
      final bottom = FocusNode(debugLabel: 'settings-bottom');
      const meta = ShellTvFocusMeta(
        tabId: 'settings',
        zone: ShellTvZone.settings,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: ShellTvContainDpad(
                    child: FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: Column(
                        children: [
                          FocusableControl(
                            focusNode: top,
                            autoFocus: true,
                            tvMeta: meta,
                            scaleOnFocus: 1.0,
                            ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                            onTap: () {},
                            child: const SizedBox(width: 200, height: 48),
                          ),
                          FocusableControl(
                            focusNode: bottom,
                            tvMeta: meta,
                            scaleOnFocus: 1.0,
                            ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                            onTap: () {},
                            child: const SizedBox(width: 200, height: 48),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(top.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        bottom.hasFocus,
        isTrue,
        reason: 'settings zone meta must not skip spatial focusInDirection',
      );

      top.dispose();
      bottom.dispose();
    },
  );

  testWidgets(
    'settings linear scope: ↓ and → both walk next (vertical list, not sideways)',
    (tester) async {
      final a = FocusNode(debugLabel: 'a');
      final b = FocusNode(debugLabel: 'b');
      final c = FocusNode(debugLabel: 'c');
      const meta = ShellTvFocusMeta(
        tabId: 'settings',
        zone: ShellTvZone.settings,
      );

      Widget row(FocusNode node, {bool autoFocus = false}) {
        return FocusableControl(
          focusNode: node,
          autoFocus: autoFocus,
          tvMeta: meta,
          scaleOnFocus: 1.0,
          ensureVisibleMode: ShellTvEnsureVisibleMode.item,
          onTap: () {},
          child: const SizedBox(width: 240, height: 40),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: ShellTvContainDpad(
                    child: ShellTvLinearFocusScope(
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Column(
                          children: [
                            row(a, autoFocus: true),
                            row(b),
                            row(c),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(a.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(b.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.hasFocus, isTrue, reason: '→ aliases next in linear settings');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(b.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(a.hasFocus, isTrue, reason: '← aliases previous in linear settings');

      a.dispose();
      b.dispose();
      c.dispose();
    },
  );

  testWidgets(
    'settings detail wraps ShellTvLinearFocusScope (vertical list)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: const Scaffold(
                body: ShellTvContainDpad(
                  child: ShellTvLinearFocusScope(
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boxCtx = tester.element(find.byType(SizedBox));
      expect(ShellTvLinearFocusScope.activeOf(boxCtx), isTrue);
      expect(ShellTvContainDpad.activeOf(boxCtx), isTrue);
    },
  );
}
