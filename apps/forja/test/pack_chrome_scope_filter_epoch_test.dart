import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';

/// Rails rebind in didChangeDependencies — counts how often that fires.
class _Dependent extends StatefulWidget {
  const _Dependent({required this.onDeps});

  final VoidCallback onDeps;

  @override
  State<_Dependent> createState() => _DependentState();
}

class _DependentState extends State<_Dependent> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PackChromeScope.maybeOf(context);
    widget.onDeps();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  final selected = ValueNotifier<Map<String, dynamic>?>(null);
  final hits = ValueNotifier<Set<String>>(const {});
  final lane = KitRowPrefetchLane();
  const child = _Dependent(onDeps: _count);

  Widget scope(String epoch) => PackChromeScope(
        eventQuery: '',
        refreshEpoch: 0,
        chromeFilterEpoch: epoch,
        viewStyle: 'cards',
        dynamicBarItems: const {},
        selectedListItem: selected,
        searchHitKindIds: hits,
        shellTabVisible: true,
        eagerLoadKeys: const {},
        pageFeedRailIds: const {},
        pageFeedFuture: null,
        rowPrefetch: lane,
        onEventQuery: (_) {},
        onBumpRefresh: ({bool forceNetwork = true}) {},
        onClearCatalog: () {},
        onViewStyle: (_) {},
        onDynamicBarItems: (_, _) {},
        onSelectListItem: (_) {},
        child: child,
      );

  setUp(() => _deps = 0);

  testWidgets('filter epoch change notifies rails without a page feed',
      (tester) async {
    await tester.pumpWidget(scope('|'));
    expect(_deps, 1);

    // Same epoch — no rebind.
    await tester.pumpWidget(scope('|'));
    expect(_deps, 1);

    // Films menu picked — rails must see the change and refetch.
    await tester.pumpWidget(scope('films||'));
    expect(_deps, 2);

    // Category picked on top.
    await tester.pumpWidget(scope('films|turkish|'));
    expect(_deps, 3);
  });
}

var _deps = 0;
void _count() => _deps++;
