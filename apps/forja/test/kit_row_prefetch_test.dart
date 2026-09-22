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

  test('late claim inside the ahead window warms immediately', () {
    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    // Continue / mood / because claim first while New Releases is still
    // below the scroll cache extent.
    for (var i = 0; i < 3; i++) {
      final index = i;
      lane.claim(() => warmed.add(index));
    }
    lane.notifyVisible(2); // on Because
    expect(warmed, isEmpty); // nothing claimed past Because yet

    // New Releases mounts → must warm without waiting for its own visibility.
    final next = lane.claim(() => warmed.add(3));
    expect(next, 3);
    expect(warmed, [3]);
    expect(lane.lastVisible, 2);
  });

  test('late claim past the ahead window stays cold', () {
    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    lane.claim(() => warmed.add(0));
    lane.notifyVisible(0);
    warmed.clear();

    // Indices 1 and 2 are inside ahead=2; 3 is not.
    lane.claim(() => warmed.add(1));
    expect(warmed, [1]);
    warmed.clear();
    lane.claim(() => warmed.add(2));
    expect(warmed, [2]);
    warmed.clear();
    lane.claim(() => warmed.add(3));
    expect(warmed, isEmpty);
  });
}
