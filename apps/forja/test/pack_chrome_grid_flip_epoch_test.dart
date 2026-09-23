import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

Widget _chrome({
  required Map<String, String> selections,
  required Widget child,
}) {
  final selected = ValueNotifier<Map<String, dynamic>?>(null);
  final hits = ValueNotifier<Set<String>>(const {});
  return PackChromeScope(
    eventQuery: '',
    refreshEpoch: 0,
    viewStyle: 'cards',
    dynamicBarItems: const {},
    selectedListItem: selected,
    shellTabVisible: true,
    eagerLoadKeys: const {},
    pageFeedRailIds: const {},
    pageFeedFuture: null,
    rowPrefetch: KitRowPrefetchLane(),
    searchHitKindIds: hits,
    onEventQuery: (_) {},
    onBumpRefresh: ({bool forceNetwork = true}) {},
    onClearCatalog: () {},
    onViewStyle: (_) {},
    onDynamicBarItems: (barId, items) {},
    onSelectListItem: (_) {},
    child: LayoutScope(
      selections: selections,
      widgetSpecs: const {},
      onSelect: (id, value, {required bool toggle}) {
        selections[id] = value;
      },
      child: child,
    ),
  );
}

void main() {
  const listSpec = {
    'kindMenu': 'cats',
    'catalogMenu': 'catalog',
    'sortMenu': 'sort',
  };

  tearDown(() {
    CategoryBarActionHost.cachedLiveListParams = const {};
  });

  testWidgets('grid flip epoch ignores portalStoreKey hydrate', (tester) async {
    final selections = <String, String>{
      'catalog': 'live',
      'cats': '10',
      'sort': 'playlist',
    };

    await tester.pumpWidget(
      _chrome(
        selections: selections,
        child: Builder(
          builder: (context) {
            final withoutPortal = packChromeGridFlipEpoch(
              context,
              listSpec: listSpec,
              tabId: 'hub',
            );
            CategoryBarActionHost.cachedLiveListParams = {
              'portalStoreKey': 'https://example|user',
            };
            final withPortal = packChromeGridFlipEpoch(
              context,
              listSpec: listSpec,
              tabId: 'hub',
            );
            expect(withoutPortal, withPortal);

            final selWithPortal = packChromeSelectionEpoch(
              context,
              listSpec: listSpec,
              tabId: 'hub',
            );
            CategoryBarActionHost.cachedLiveListParams = const {};
            final selWithoutPortal = packChromeSelectionEpoch(
              context,
              listSpec: listSpec,
              tabId: 'hub',
            );
            expect(selWithPortal, isNot(selWithoutPortal));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('grid flip epoch changes when Live category changes',
      (tester) async {
    final selections = <String, String>{
      'catalog': 'live',
      'cats': '10',
      'sort': 'playlist',
    };

    await tester.pumpWidget(
      _chrome(
        selections: selections,
        child: Builder(
          builder: (context) {
            final a = packChromeGridFlipEpoch(
              context,
              listSpec: listSpec,
              tabId: 'hub',
            );
            selections['cats'] = '20';
            final b = packChromeGridFlipEpoch(
              context,
              listSpec: listSpec,
              tabId: 'hub',
            );
            expect(a, isNot(b));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('empty-grid placeholder only after flip epoch latched', () {
    // Mirrors PackLoadedPaint didChangeDependencies gate.
    bool shouldEmpty({
      required String appliedFlip,
      required String nextFlip,
      required bool shelfFlipped,
      required bool vodPaged,
    }) {
      if (shelfFlipped || !vodPaged) return false;
      if (appliedFlip.isEmpty) return false;
      return appliedFlip != nextFlip;
    }

    expect(
      shouldEmpty(
        appliedFlip: '',
        nextFlip: 'live|10',
        shelfFlipped: false,
        vodPaged: true,
      ),
      isFalse,
      reason: 'initial hub-open latch must keep warm channels',
    );
    expect(
      shouldEmpty(
        appliedFlip: 'live|10',
        nextFlip: 'live|10',
        shelfFlipped: false,
        vodPaged: true,
      ),
      isFalse,
      reason: 'portal hydrate alone does not change flip epoch',
    );
    expect(
      shouldEmpty(
        appliedFlip: 'live|10',
        nextFlip: 'live|20',
        shelfFlipped: false,
        vodPaged: true,
      ),
      isTrue,
      reason: 'real category flip clears the grid in place',
    );
  });
}
