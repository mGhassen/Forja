import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/row_prefetch.dart';

void main() {
  test('notifyVisible warms the next kKitRowPrefetchAhead rows only', () {
    expect(kKitRowPrefetchAhead, 3);

    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    for (var i = 0; i < 8; i++) {
      final index = i;
      lane.claim(() => warmed.add(index));
    }

    lane.notifyVisible(0);
    expect(warmed, [1, 2, 3]);

    warmed.clear();
    lane.notifyVisible(3);
    expect(warmed, [4, 5, 6]);
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

  test('on Continue, New Releases is inside ahead=3', () {
    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    // popular(0) continue(1) mood(2) because(3) new_releases(4)
    for (var i = 0; i < 5; i++) {
      final index = i;
      lane.claim(() => warmed.add(index));
    }
    warmed.clear();
    lane.notifyVisible(1); // Continue
    expect(warmed, [2, 3, 4]); // mood, because, new_releases
  });

  test('late claim past the ahead window stays cold', () {
    final warmed = <int>[];
    final lane = KitRowPrefetchLane();
    lane.claim(() => warmed.add(0));
    lane.notifyVisible(0);
    warmed.clear();

    // Indices 1..3 are inside ahead=3; 4 is not.
    for (var i = 1; i <= 3; i++) {
      final index = i;
      lane.claim(() => warmed.add(index));
      expect(warmed, [index]);
      warmed.clear();
    }
    lane.claim(() => warmed.add(4));
    expect(warmed, isEmpty);
  });
}
