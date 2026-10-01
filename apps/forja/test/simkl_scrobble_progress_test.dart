import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';

void main() {
  group('SimklService.progressPercent', () {
    test('maps position/duration to 0–100', () {
      expect(SimklService.progressPercent(0, 100000), 0);
      expect(SimklService.progressPercent(50000, 100000), 50);
      expect(SimklService.progressPercent(100000, 100000), 100);
      expect(SimklService.progressPercent(33333, 100000), 33.33);
    });

    test('guards bad duration / overflow', () {
      expect(SimklService.progressPercent(30, 0), 0);
      expect(SimklService.progressPercent(-1, 100000), 0);
      expect(SimklService.progressPercent(200000, 100000), 100);
    });
  });
}
