import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_open_mode.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// kit.list `open: 'bind'` + `bind{}` + `accessory` are pack-declared wire.
/// Synthetic specs only — no shipped pack ids.
void main() {
  group('resolveKitListTapOpen bind matrix', () {
    const cases = <(String, bool, bool, KitListTapOpen)>[
      ('bind', false, true, KitListTapOpen.bind),
      ('bind', false, false, KitListTapOpen.bind),
      ('BIND', false, false, KitListTapOpen.bind),
      ('bind', true, true, KitListTapOpen.panel),
      ('bind', true, false, KitListTapOpen.details),
      ('', false, true, KitListTapOpen.openTap),
      ('', true, true, KitListTapOpen.panel),
      ('panel', false, true, KitListTapOpen.panel),
      ('details', false, true, KitListTapOpen.details),
      ('play', false, true, KitListTapOpen.play),
    ];
    for (final (mode, managed, side, want) in cases) {
      test('open=$mode managed=$managed sidePanel=$side → $want', () {
        expect(
          resolveKitListTapOpen(
            openMode: mode,
            hasMatchOpenSurface: managed,
            canShowSidePanel: side,
          ),
          want,
        );
      });
    }
  });

  Future<CatalogCardsGrid> mountList(
    WidgetTester tester,
    Map<String, dynamic> list,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: forjaThemeData(),
        home: Scaffold(
          body: PackPaintTree(
            pluginId: 'test-hub-a',
            // Inline `items` mount the list painter directly (no engine load).
            spec: {
              'type': 'test.list',
              'id': 'grid',
              'items': const [],
              ...list,
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<CatalogCardsGrid>(find.byType(CatalogCardsGrid));
  }

  group('PackPaintTree kit.list', () {
    testWidgets('open bind + bind{} wires long-press and declared accessory', (
      tester,
    ) async {
      final grid = await mountList(tester, {
        'open': 'bind',
        'bind': {'title': 'Pick a hub'},
        'accessory': 'listPin',
      });
      expect(grid.onItemLongPress, isNotNull);
      expect(grid.itemAccessory, isNotNull);
    });

    testWidgets('no open / no bind / no accessory → nothing wired', (
      tester,
    ) async {
      final grid = await mountList(tester, const {});
      expect(grid.onItemLongPress, isNull);
      expect(grid.itemAccessory, isNull);
    });

    testWidgets('bind.rebind false → tap binds but long-press is off', (
      tester,
    ) async {
      final grid = await mountList(tester, {
        'open': 'bind',
        'bind': {'title': 'Pick a hub', 'rebind': false},
      });
      expect(grid.onItemLongPress, isNull);
    });

    testWidgets('open bind without bind.title → plain open, no long-press', (
      tester,
    ) async {
      final grid = await mountList(tester, {
        'open': 'bind',
        'bind': {'pickTitle': 'x'},
      });
      expect(grid.onItemLongPress, isNull);
    });

    testWidgets('accessory map resolves by card kind', (tester) async {
      final channel = await mountList(tester, {
        'cardKind': 'channel',
        'accessory': {'channel': 'favorite'},
      });
      expect(channel.itemAccessory, isNotNull);
      final poster = await mountList(tester, {
        'cardKind': 'poster',
        'accessory': {'channel': 'favorite'},
      });
      expect(poster.itemAccessory, isNull);
      final fallback = await mountList(tester, {
        'cardKind': 'poster',
        'accessory': {'channel': 'favorite', 'default': 'listPin'},
      });
      expect(fallback.itemAccessory, isNotNull);
    });

    testWidgets('managed-open list (panelTabs) ignores bind + accessory', (
      tester,
    ) async {
      final grid = await mountList(tester, {
        'open': 'bind',
        'panelTabs': [
          {'id': 'alpha', 'label': 'Alpha'},
        ],
        'bind': {'title': 'Pick a hub'},
        'accessory': 'listPin',
      });
      expect(grid.onItemLongPress, isNull);
      expect(grid.itemAccessory, isNull);
    });
  });
}
