import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/focus/focus_edge.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

void main() {
  group('kitFocusEdge', () {
    test('skips missing row ids', () {
      expect(kitFocusEdge('tab', null), isNull);
      expect(kitFocusEdge('tab', ''), isNull);
      expect(kitFocusEdge('tab', '  '), isNull);
      expect(kitFocusSide('tab', null), isNull);
      expect(kitFocusSide('tab', ''), isNull);
    });

    test('returns a jump for a named row', () {
      expect(kitFocusEdge('tab', 'grid'), isNotNull);
      expect(kitFocusEdge('tab', 'status', last: true), isNotNull);
      expect(kitFocusEdge('tab', 'chrome', lastItem: true), isNotNull);
      expect(kitFocusSide('tab', 'sources-kind'), isNotNull);
    });

    test('marks miss when target row is unregistered', () {
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      kitFocusEdge('orphan-tab', 'sources-kind', last: true)!.call();
      expect(ShellTvFocusCoordinator.takeKitEdgeMiss(), isTrue);
    });

    test('portals+lastItem remaps to chrome last', () {
      expect(kitFocusEdge('tab', 'portals', lastItem: true), isNotNull);
      // focusRight portals (no lastItem) stays the portals panel row.
      expect(kitFocusEdge('tab', 'portals', last: true), isNotNull);
    });

    test('kitFocusChromeAt marks miss when chrome is unregistered', () {
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      kitFocusChromeAt('orphan-tab', 1)();
      expect(ShellTvFocusCoordinator.takeKitEdgeMiss(), isTrue);
    });

    test('portals+lastItem remaps miss when chrome is unregistered', () {
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      kitFocusEdge('orphan-tab', 'portals', lastItem: true)!.call();
      expect(ShellTvFocusCoordinator.takeKitEdgeMiss(), isTrue);
    });

    testWidgets(
      'hero-details reveals and focuses defaultFocus (View details)',
      (tester) async {
        const tab = 'catalog';
        final details = FocusNode(debugLabel: 'hero-details');
        addTearDown(() {
          details.dispose();
          ShellTvFocusCoordinator.clearTab(tab);
        });

        ShellTvFocusCoordinator.setNavOrder([tab]);
        ShellTvFocus.currentNavTabId = tab;
        ShellTvFocusCoordinator.clearTab(tab);
        TvHeroActions.bind(tab, defaultFocus: () => details);

        await tester.pumpWidget(
          MaterialApp(
            home: Focus(
              focusNode: details,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        );
        await tester.pump();

        ShellTvFocusCoordinator.beginKitEdgeAttempt();
        kitFocusEdge(tab, kHubHeroDetailsFocusId)!.call();
        await tester.pump();

        expect(ShellTvFocusCoordinator.takeKitEdgeMiss(), isFalse);
        expect(details.hasPrimaryFocus, isTrue);
      },
    );

    test('hero-details marks miss when defaultFocus cannot land', () {
      const tab = 'orphan-hero';
      ShellTvFocusCoordinator.clearTab(tab);
      ShellTvFocusCoordinator.beginKitEdgeAttempt();
      kitFocusEdge(tab, kHubHeroDetailsFocusId)!.call();
      expect(ShellTvFocusCoordinator.takeKitEdgeMiss(), isTrue);
    });

    testWidgets('RIGHT does not swallow when kit edge misses', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            focusNode: node,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      final edge = kitFocusEdge('missing-tab', 'sources-kind', last: true)!;
      final result = shellTvHandleRowArrows(
        event: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
        onRightEdge: edge,
      );
      // Unregistered row → ignored so spatial / parent can handle.
      expect(result, KeyEventResult.ignored);
    });

    testWidgets('DOWN does not swallow when Featured kit edge misses',
        (tester) async {
      final node = FocusNode(debugLabel: 'hero-details');
      addTearDown(() {
        node.dispose();
        ShellTvFocusCoordinator.clearTab('home-miss');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            focusNode: node,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      // Same path as hero View details → bleed: kitFocusEdge to a missing row.
      final edge = kitFocusEdge('home-miss', 'featured')!;
      final result = shellTvHandleRowArrows(
        event: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
        tvMeta: ShellTvFocusMeta(
          tabId: 'home-miss',
          zone: ShellTvZone.row,
          rowId: kHubHeroDetailsFocusId,
          itemIndex: 0,
        ),
        onDownEdge: edge,
      );
      expect(result, KeyEventResult.ignored);
      expect(node.hasPrimaryFocus, isTrue);
    });
  });
}
