import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';

void main() {
  test('notifyVisible warms the next kKitRowPrefetchAhead rows only', () {
    expect(kKitRowPrefetchAhead, 2);

    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    for (var i = 0; i < 6; i++) {
      final index = i;
      lane.claim(() => warmed.add(index));
    }

    lane.notifyVisible(0);
    expect(warmed, [1, 2]);

    warmed.clear();
    lane.notifyVisible(2);
    expect(warmed, [3, 4]);
  });

  test('notifyVisible stops at the end of the lane', () {
    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    for (var i = 0; i < 3; i++) {
      final index = i;
      lane.claim(() => warmed.add(index));
    }

    lane.notifyVisible(1);
    expect(warmed, [2]);
  });
}
