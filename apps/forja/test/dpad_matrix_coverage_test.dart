import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hub_page_focus.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

Widget _wrapTv(String tabId, Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: ShellInputPolicy.maybeWrapFocusTraversal(
          enabled: true,
          child: FocusScope(
            child: TvFocusGraph(tabId: tabId, child: child),
          ),
        ),
      ),
    ),
  );
}

Widget _rowItem({
  required String tabId,
  required String rowId,
  required int index,
  required FocusNode node,
  VoidCallback? onUp,
  VoidCallback? onDown,
  VoidCallback? onLeft,
  VoidCallback? onRight,
  bool autoFocus = false,
}) {
  return FocusableControl(
    focusNode: node,
    autoFocus: autoFocus,
    scaleOnFocus: 1.0,
    ensureVisibleMode: ShellPaintEnsureVisible.off,
    onUpEdge: onUp,
    onDownEdge: onDown,
    onLeftEdge: onLeft,
    onRightEdge: onRight,
    tvMeta: ShellTvFocusMeta(
      tabId: tabId,
      zone: ShellTvZone.row,
      rowId: rowId,
      itemIndex: index,
    ),
    onTap: () {},
    child: SizedBox(width: 80, height: 40, child: Text('$rowId-$index')),
  );
}

void main() {
  tearDown(() {
    ShellTvFocusCoordinator.clearTab('iptv');
    ShellTvFocusCoordinator.clearTab('live_sports');
    ShellTvFocusCoordinator.clearTab('mylist');
    ShellTvFocusCoordinator.clearTab('settings');
    ShellTvFocusCoordinator.clearTab('home');
  });

  group('HubPageFocus bind land + pageBack', () {
    testWidgets('enter lands remembered cats; pageBack items→cats',
        (tester) async {
      const tab = 'iptv';
      ShellTvFocus.currentNavTabId = tab;
      ShellTvFocusCoordinator.setNavOrder([tab]);

      final cat0 = FocusNode(debugLabel: 'cat-0');
      final cat1 = FocusNode(debugLabel: 'cat-1');
      final item0 = FocusNode(debugLabel: 'item-0');
      addTearDown(() {
        cat0.dispose();
        cat1.dispose();
        item0.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'cats',
                sortOrder: 1,
                itemCount: 2,
                orientation: ShellTvRowOrientation.horizontal,
                child: Row(
                  children: [
                    _rowItem(
                      tabId: tab,
                      rowId: 'cats',
                      index: 0,
                      node: cat0,
                    ),
                    _rowItem(
                      tabId: tab,
                      rowId: 'cats',
                      index: 1,
                      node: cat1,
                    ),
                  ],
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'items',
                sortOrder: 2,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'items',
                  index: 0,
                  node: item0,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // Remember last cats index = 1 via coordinator (updates lastFocusedIndex).
      expect(
        ShellTvFocusCoordinator.focusRowItemExact(tab, 'cats', 1),
        isTrue,
      );
      await tester.pump();
      expect(cat1.hasFocus, isTrue);

      bindHubPageFocus(
        tab,
        HubPageFocus.parse({
          'focus': {
            'enter': 'cats',
            'restore': 'cats',
            'restoreMode': 'remembered',
            'pageBack': ['items', 'cats'],
          },
        }),
      );

      expect(
        ShellTvFocusCoordinator.focusRowItemExact(tab, 'items', 0),
        isTrue,
      );
      await tester.pump();
      expect(item0.hasFocus, isTrue);

      expect(ShellTvFocusCoordinator.focusTabEnterFromNav(tab), isTrue);
      await tester.pump();
      expect(cat1.hasFocus, isTrue, reason: 'enter lands remembered cats');

      // pageBack from items → cats.
      expect(
        ShellTvFocusCoordinator.focusRowItemExact(tab, 'items', 0),
        isTrue,
      );
      await tester.pump();
      expect(ShellTvFocusCoordinator.tryPageBack(tab), isTrue);
      await tester.pump();
      expect(cat1.hasFocus, isTrue, reason: 'pageBack items→cats remembered');
    });
  });

  group('Hub spines (IPTV / Live / Lists)', () {
    testWidgets('IPTV cats↑↓ stay in panel; →/← hop cats↔items',
        (tester) async {
      const tab = 'iptv';
      ShellTvFocus.currentNavTabId = tab;
      final cat0 = FocusNode();
      final cat1 = FocusNode();
      final item = FocusNode();
      addTearDown(() {
        cat0.dispose();
        cat1.dispose();
        item.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'cats',
                sortOrder: 1,
                itemCount: 2,
                orientation: ShellTvRowOrientation.vertical,
                onFocusDown: () {},
                child: Column(
                  children: [
                    _rowItem(
                      tabId: tab,
                      rowId: 'cats',
                      index: 0,
                      node: cat0,
                      autoFocus: true,
                    ),
                    _rowItem(
                      tabId: tab,
                      rowId: 'cats',
                      index: 1,
                      node: cat1,
                    ),
                  ],
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'items',
                sortOrder: 2,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'items',
                  index: 0,
                  node: item,
                  onLeft: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'cats', 0);
                  },
                  onRight: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'items', 0);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(cat0.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(cat1.hasFocus, isTrue, reason: '↓ scrolls cats, not items');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(cat1.hasFocus, isTrue, reason: 'last cat ↓ traps');

      // → into items via explicit edge (pack focusRight).
      ShellTvFocusCoordinator.focusRowItem(tab, 'items', 0);
      await tester.pump();
      expect(item.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(cat0.hasFocus, isTrue, reason: '← from items → cats');
    });

    testWidgets('Live kind↓schedule; schedule→ miss does not swallow',
        (tester) async {
      const tab = 'live_sports';
      ShellTvFocus.currentNavTabId = tab;
      final kind = FocusNode();
      final schedule = FocusNode();
      addTearDown(() {
        kind.dispose();
        schedule.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'kind',
                sortOrder: 1,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'kind',
                  index: 0,
                  node: kind,
                  autoFocus: true,
                  onDown: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'schedule', 0);
                  },
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'schedule',
                sortOrder: 2,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'schedule',
                  index: 0,
                  node: schedule,
                  onUp: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'kind', 0);
                  },
                  // Pack focusRight: sources-kind — unregistered → miss.
                  onRight: () {
                    final ok = ShellTvFocusCoordinator.focusRowItemRemembered(
                      tab,
                      'sources-kind',
                    );
                    if (!ok) ShellTvFocusCoordinator.markKitEdgeMiss();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(schedule.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      // Miss must not leave focus stuck dead — schedule still focused.
      expect(schedule.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(kind.hasFocus, isTrue);
    });

    testWidgets('My List kind↓status↓grid + pageBack ladder', (tester) async {
      const tab = 'mylist';
      ShellTvFocus.currentNavTabId = tab;
      final kind = FocusNode();
      final status = FocusNode();
      final grid = FocusNode();
      addTearDown(() {
        kind.dispose();
        status.dispose();
        grid.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'kind',
                sortOrder: 0,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'kind',
                  index: 0,
                  node: kind,
                  onDown: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'status', 0);
                  },
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'status',
                sortOrder: 1,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'status',
                  index: 0,
                  node: status,
                  onUp: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'kind', 0);
                  },
                  onDown: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'grid', 0);
                  },
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'grid',
                sortOrder: 2,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'grid',
                  index: 0,
                  node: grid,
                  autoFocus: true,
                  onUp: () {
                    ShellTvFocusCoordinator.focusRowItem(tab, 'status', 0);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(grid.hasFocus, isTrue);

      bindHubPageFocus(
        tab,
        HubPageFocus.parse({
          'focus': {
            'enter': 'kind',
            'restore': 'kind',
            'restoreMode': 'remembered',
            'pageBack': ['grid', 'status', 'kind'],
          },
        }),
      );

      expect(ShellTvFocusCoordinator.tryPageBack(tab), isTrue);
      await tester.pump();
      expect(status.hasFocus, isTrue);

      expect(ShellTvFocusCoordinator.tryPageBack(tab), isTrue);
      await tester.pump();
      expect(kind.hasFocus, isTrue);

      expect(ShellTvFocusCoordinator.tryPageBack(tab), isFalse);
    });
  });

  group('Settings I127 A01/A04/A07 primitives', () {
    testWidgets('A02: pageBack detail→selected category; next Back yields false',
        (tester) async {
      const tab = 'settings';
      ShellTvFocus.currentNavTabId = tab;
      ShellTvFocusCoordinator.setNavOrder([tab, 'home']);
      final cat0 = FocusNode();
      final cat1 = FocusNode();
      final detail = FocusNode();
      addTearDown(() {
        cat0.dispose();
        cat1.dispose();
        detail.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'settings-categories',
                sortOrder: 0,
                itemCount: 2,
                orientation: ShellTvRowOrientation.vertical,
                child: Column(
                  children: [
                    _rowItem(
                      tabId: tab,
                      rowId: 'settings-categories',
                      index: 0,
                      node: cat0,
                    ),
                    _rowItem(
                      tabId: tab,
                      rowId: 'settings-categories',
                      index: 1,
                      node: cat1,
                    ),
                  ],
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'settings-detail',
                sortOrder: 100,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'settings-detail',
                  index: 0,
                  node: detail,
                  autoFocus: true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // Selected category = index 1 (Playback-like).
      expect(
        ShellTvFocusCoordinator.focusRowItemExact(
          tab,
          'settings-categories',
          1,
        ),
        isTrue,
      );
      await tester.pump();
      expect(
        ShellTvFocusCoordinator.focusRowItemExact(tab, 'settings-detail', 0),
        isTrue,
      );
      await tester.pump();

      TvHeroActions.bind(
        tab,
        pageBack: () {
          if (detail.hasFocus) {
            return ShellTvFocusCoordinator.focusRowItemRemembered(
              tab,
              'settings-categories',
            );
          }
          return false;
        },
      );

      expect(ShellTvFocusCoordinator.tryPageBack(tab), isTrue);
      await tester.pump();
      expect(cat1.hasFocus, isTrue, reason: 'Back returns to selected category');

      expect(
        ShellTvFocusCoordinator.tryPageBack(tab),
        isFalse,
        reason: 'further Back leaves to shell nav',
      );
    });

    testWidgets('A01: → enters detail; ↑ stays; ← exits', (tester) async {
      final category = FocusNode(debugLabel: 'cat');
      final detailA = FocusNode(debugLabel: 'detail-a');
      final detailB = FocusNode(debugLabel: 'detail-b');
      var exited = false;
      addTearDown(() {
        category.dispose();
        detailA.dispose();
        detailB.dispose();
      });

      const detailMeta = ShellTvFocusMeta(
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
                  body: Row(
                    children: [
                      FocusableControl(
                        focusNode: category,
                        autoFocus: true,
                        scaleOnFocus: 1.0,
                        onRightEdge: () => detailA.requestFocus(),
                        onTap: () => detailA.requestFocus(),
                        tvMeta: const ShellTvFocusMeta(
                          tabId: 'settings',
                          zone: ShellTvZone.row,
                          rowId: 'settings-categories',
                          itemIndex: 0,
                        ),
                        child: const SizedBox(width: 120, height: 40),
                      ),
                      Expanded(
                        child: ShellTvContainDpad(
                          child: ShellTvLinearFocusEdges(
                            onBackwardEdge: () {
                              exited = true;
                              category.requestFocus();
                              return true;
                            },
                            child: Column(
                              children: [
                                FocusableControl(
                                  focusNode: detailA,
                                  scaleOnFocus: 1.0,
                                  tvMeta: detailMeta,
                                  onTap: () {},
                                  child: const SizedBox(width: 200, height: 40),
                                ),
                                FocusableControl(
                                  focusNode: detailB,
                                  scaleOnFocus: 1.0,
                                  tvMeta: detailMeta,
                                  onTap: () {},
                                  child: const SizedBox(width: 200, height: 40),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(category.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(detailA.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(detailA.hasFocus, isTrue);
      expect(exited, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(detailB.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(exited, isTrue);
      expect(category.hasFocus, isTrue);
    });

    testWidgets('A04: ↑ from addon IPTV lands Playback, not categories',
        (tester) async {
      const tab = 'settings';
      ShellTvFocus.currentNavTabId = tab;
      final categories = FocusNode();
      final playback = FocusNode();
      final iptv = FocusNode();
      addTearDown(() {
        categories.dispose();
        playback.dispose();
        iptv.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'settings-categories',
                sortOrder: 0,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'settings-categories',
                  index: 0,
                  node: categories,
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'addon-playback',
                sortOrder: 100,
                itemCount: 1,
                onFocusUp: () {},
                child: _rowItem(
                  tabId: tab,
                  rowId: 'addon-playback',
                  index: 0,
                  node: playback,
                  onUp: () {},
                ),
              ),
              TvKitRow(
                tabId: tab,
                rowId: 'addon-iptv',
                sortOrder: 101,
                itemCount: 1,
                onFocusUp: () {
                  ShellTvFocusCoordinator.focusRowItem(
                    tab,
                    'addon-playback',
                    0,
                  );
                },
                child: _rowItem(
                  tabId: tab,
                  rowId: 'addon-iptv',
                  index: 0,
                  node: iptv,
                  autoFocus: true,
                  onUp: () {
                    ShellTvFocusCoordinator.focusRowItem(
                      tab,
                      'addon-playback',
                      0,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(iptv.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(playback.hasFocus, isTrue);
      expect(categories.hasFocus, isFalse);
    });

    testWidgets('A07: packs chip ↑ traps — never categories', (tester) async {
      const tab = 'settings';
      ShellTvFocus.currentNavTabId = tab;
      final categories = FocusNode();
      final chip = FocusNode();
      addTearDown(() {
        categories.dispose();
        chip.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          Column(
            children: [
              TvKitRow(
                tabId: tab,
                rowId: 'settings-categories',
                sortOrder: 0,
                itemCount: 1,
                child: _rowItem(
                  tabId: tab,
                  rowId: 'settings-categories',
                  index: 0,
                  node: categories,
                ),
              ),
              // Packs chip strip uses sortOrder 100+ and empty onFocusUp trap.
              TvKitRow(
                tabId: tab,
                rowId: 'packs-chips',
                sortOrder: 100,
                itemCount: 1,
                onFocusUp: () {},
                child: _rowItem(
                  tabId: tab,
                  rowId: 'packs-chips',
                  index: 0,
                  node: chip,
                  autoFocus: true,
                  onUp: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(chip.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(chip.hasFocus, isTrue);
      expect(categories.hasFocus, isFalse);
    });
  });

  group('Portals header + sources claim', () {
    testWidgets('portals header ↓ lands portals list', (tester) async {
      const tab = 'iptv';
      ShellTvFocus.currentNavTabId = tab;
      final header = FocusNode();
      final portal = FocusNode();
      addTearDown(() {
        header.dispose();
        portal.dispose();
      });

      await tester.pumpWidget(
        _wrapTv(
          tab,
          ShellTvContainDpad(
            child: Column(
              children: [
                TvKitRow(
                  tabId: tab,
                  rowId: 'portals-header',
                  sortOrder: 0,
                  itemCount: 1,
                  child: _rowItem(
                    tabId: tab,
                    rowId: 'portals-header',
                    index: 0,
                    node: header,
                    autoFocus: true,
                    onDown: () {
                      ShellTvFocusCoordinator.focusRowItem(tab, 'portals', 0);
                    },
                  ),
                ),
                TvKitRow(
                  tabId: tab,
                  rowId: 'portals',
                  sortOrder: 1,
                  itemCount: 1,
                  orientation: ShellTvRowOrientation.vertical,
                  child: _rowItem(
                    tabId: tab,
                    rowId: 'portals',
                    index: 0,
                    node: portal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(header.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(portal.hasFocus, isTrue);
    });
  });
}
