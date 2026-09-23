import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/lazy_viewport_gate.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    debugResetLazyViewportGateActivatedKeys();
  });

  PackChromeScope chrome({
    required KitRowPrefetchLane lane,
    required Widget child,
  }) {
    return PackChromeScope(
      eventQuery: '',
      refreshEpoch: 0,
      viewStyle: '',
      dynamicBarItems: const {},
      selectedListItem: ValueNotifier(null),
      searchHitKindIds: ValueNotifier(const {}),
      shellTabVisible: true,
      eagerLoadKeys: const {},
      pageFeedRailIds: const {},
      pageFeedFuture: null,
      rowPrefetch: lane,
      onEventQuery: (_) {},
      onClearCatalog: () {},
      onBumpRefresh: ({bool forceNetwork = true}) {},
      onViewStyle: (_) {},
      onDynamicBarItems: (_, __) {},
      onSelectListItem: (_) {},
      child: child,
    );
  }

  Widget gate(
    String id, {
    required double height,
    bool eager = false,
    required List<String> activated,
  }) {
    return LazyViewportGate(
      key: ValueKey('gate-$id'),
      detectorKey: Key('lazy-$id'),
      placeholderHeight: height,
      eager: eager,
      placeholder: SizedBox(height: height, child: Text('ph-$id')),
      builder: (context) {
        if (!activated.contains(id)) activated.add(id);
        return SizedBox(height: height, child: Text('body-$id'));
      },
    );
  }

  testWidgets(
    'visible row warms the next kKitRowPrefetchAhead gated rows',
    (tester) async {
      expect(kKitRowPrefetchAhead, 3);
      final lane = KitRowPrefetchLane();
      final activated = <String>[];
      final controller = ScrollController();

      // Short viewport so only row0 fits — proves ahead=3, not cascade from
      // a second on-screen row.
      await tester.pumpWidget(
        MaterialApp(
          home: chrome(
            lane: lane,
            child: Scaffold(
              body: SizedBox(
                // Exactly one row tall — jumpTo(200) shows only row0.
                height: 200,
                child: ListView(
                  controller: controller,
                  cacheExtent: 2000,
                  children: [
                    const SizedBox(height: 200, child: Text('top')),
                    gate('row0', height: 200, eager: true, activated: activated),
                    gate('row1', height: 200, activated: activated),
                    gate('row2', height: 200, activated: activated),
                    gate('row3', height: 200, activated: activated),
                    gate('row4', height: 200, activated: activated),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // view 200–400: only row0.
      controller.jumpTo(200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(activated.contains('row0'), isTrue);
      expect(activated.contains('row1'), isTrue);
      expect(activated.contains('row2'), isTrue);
      expect(activated.contains('row3'), isTrue);
      expect(
        activated.contains('row4'),
        isFalse,
        reason: 'row4 is past ahead=3 from the single visible row',
      );
    },
  );

  testWidgets(
    'prefetch-activated row notifies when it enters the viewport',
    (tester) async {
      final lane = KitRowPrefetchLane();
      final activated = <String>[];
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: chrome(
            lane: lane,
            child: Scaffold(
              body: SizedBox(
                height: 250,
                child: ListView(
                  controller: controller,
                  cacheExtent: 800,
                  children: [
                    const SizedBox(height: 200, child: Text('top')),
                    gate('because', height: 200, eager: true, activated: activated),
                    gate('new_releases', height: 200, activated: activated),
                    gate('genre_0', height: 200, activated: activated),
                    gate('genre_1', height: 200, activated: activated),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      controller.jumpTo(180);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(activated.contains('because'), isTrue);
      expect(activated.contains('new_releases'), isTrue);

      controller.jumpTo(400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        activated.contains('genre_0'),
        isTrue,
        reason: 'next rows under a visible rail must prefetch',
      );
    },
  );
}
