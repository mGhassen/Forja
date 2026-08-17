import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('bufferedEndFromCacheAhead', () {
    test('uses seconds ahead of playhead', () {
      expect(
        bufferedEndFromCacheAhead(
          position: const Duration(seconds: 10),
          duration: const Duration(minutes: 120),
          aheadSecs: 45,
        ),
        const Duration(seconds: 55),
      );
    });

    test('prefers further cache-time PTS', () {
      expect(
        bufferedEndFromCacheAhead(
          position: const Duration(seconds: 10),
          duration: const Duration(minutes: 120),
          aheadSecs: 5,
          cacheTime: const Duration(seconds: 40),
        ),
        const Duration(seconds: 40),
      );
    });

    test('clamps to duration', () {
      expect(
        bufferedEndFromCacheAhead(
          position: const Duration(seconds: 110),
          duration: const Duration(seconds: 120),
          aheadSecs: 45,
        ),
        const Duration(seconds: 120),
      );
    });

    test('null when nothing ahead', () {
      expect(
        bufferedEndFromCacheAhead(
          position: Duration.zero,
          duration: const Duration(minutes: 120),
          aheadSecs: 0,
        ),
        isNull,
      );
    });
  });
}
