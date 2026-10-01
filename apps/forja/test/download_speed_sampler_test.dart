import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_speed_sampler.dart';

void main() {
  group('DownloadSpeedSampler', () {
    test('etaSecondsFor is null when speed is zero or remaining is empty', () {
      final sampler = DownloadSpeedSampler();
      expect(sampler.etaSecondsFor(1_000_000), isNull);
      expect(sampler.etaSecondsFor(0), isNull);
      expect(sampler.etaSecondsFor(-1), isNull);
    });

    test('closed window updates speed and eta', () async {
      final sampler = DownloadSpeedSampler(alpha: 1.0);
      expect(sampler.addBytes(1024 * 1024), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(sampler.addBytes(0), isTrue);
      expect(sampler.speedBytesPerSec, greaterThan(0));
      final eta = sampler.etaSecondsFor(10 * 1024 * 1024);
      expect(eta, isNotNull);
      expect(eta!, greaterThan(0));
    });

    test('between windows speed stays non-zero after first sample', () async {
      final sampler = DownloadSpeedSampler(alpha: 0.5);
      expect(sampler.addBytes(2 * 1024 * 1024), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(sampler.addBytes(0), isTrue);
      final afterFirst = sampler.speedBytesPerSec;
      expect(afterFirst, greaterThan(0));

      // Mid-window progress must not zero the display rate.
      expect(sampler.addBytes(64 * 1024), isFalse);
      expect(sampler.speedBytesPerSec, afterFirst);
    });

    test('reset clears smoothed speed', () async {
      final sampler = DownloadSpeedSampler(alpha: 1.0);
      sampler.addBytes(1024 * 1024);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      sampler.addBytes(0);
      expect(sampler.speedBytesPerSec, greaterThan(0));
      sampler.reset();
      expect(sampler.speedBytesPerSec, 0);
    });
  });
}
