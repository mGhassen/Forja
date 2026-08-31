import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/utils/bounded_parallel.dart';

void main() {
  test('mapBoundedParallel preserves order and drops nulls', () async {
    final out = await mapBoundedParallel<int, String>(
      items: [1, 2, 3, 4],
      concurrency: 2,
      work: (n, _) async {
        await Future<void>.delayed(Duration(milliseconds: 5 * (5 - n)));
        if (n == 3) return null;
        return 'n$n';
      },
    );
    expect(out, ['n1', 'n2', 'n4']);
  });

  test('mapBoundedParallel stops launching after cancel', () async {
    var started = 0;
    final out = await mapBoundedParallel<int, int>(
      items: [1, 2, 3, 4, 5],
      concurrency: 1,
      isCancelled: () => started >= 2,
      work: (n, _) async {
        started++;
        return n;
      },
    );
    expect(started, lessThanOrEqualTo(3));
    expect(out.length, lessThanOrEqualTo(started));
  });
}
