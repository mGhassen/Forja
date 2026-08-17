import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/nuvio/nuvio_runtime.dart';

void main() {
  group('NuvioJsMutex', () {
    test('runs critical sections one at a time', () async {
      final mutex = NuvioJsMutex();
      final order = <int>[];
      final started = <int>[];

      Future<void> job(int id, int ms) => mutex.run(() async {
            started.add(id);
            await Future<void>.delayed(Duration(milliseconds: ms));
            order.add(id);
          });

      await Future.wait([
        job(1, 40),
        job(2, 10),
        job(3, 10),
      ]);

      expect(started, [1, 2, 3]);
      expect(order, [1, 2, 3]);
    });

    test('releases the lock when the action throws', () async {
      final mutex = NuvioJsMutex();
      await expectLater(
        mutex.run(() async {
          throw StateError('boom');
        }),
        throwsStateError,
      );
      var ran = false;
      await mutex.run(() async {
        ran = true;
      });
      expect(ran, isTrue);
    });
  });
}
