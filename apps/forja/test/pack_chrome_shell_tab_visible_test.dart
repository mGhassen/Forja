import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';

PackChromeScope _chrome({
  required bool shellTabVisible,
  required Widget child,
}) {
  return PackChromeScope(
    eventQuery: '',
    refreshEpoch: 0,
    viewStyle: '',
    dynamicBarItems: const {},
    selectedListItem: ValueNotifier(null),
    searchHitKindIds: ValueNotifier(const {}),
    shellTabVisible: shellTabVisible,
    eagerLoadKeys: const {},
    pageFeedRailIds: const {},
    pageFeedFuture: null,
    rowPrefetch: KitRowPrefetchLane(),
    onEventQuery: (_) {},
    onClearCatalog: () {},
    onBumpRefresh: ({bool forceNetwork = true}) {},
    onViewStyle: (_) {},
    onDynamicBarItems: (_, __) {},
    onSelectListItem: (_) {},
    child: child,
  );
}

void main() {
  test('PackChromeScope notifies when shellTabVisible flips', () {
    final a = _chrome(
      shellTabVisible: true,
      child: const SizedBox.shrink(),
    );
    final b = _chrome(
      shellTabVisible: false,
      child: const SizedBox.shrink(),
    );
    expect(b.updateShouldNotify(a), isTrue);
    expect(a.updateShouldNotify(b), isTrue);
    expect(a.updateShouldNotify(a), isFalse);
  });
}
