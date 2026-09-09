import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv_proxy_reconnect_skip.dart';

void main() {
  group('iptvProxyReconnectSkipBytes', () {
    test('fallback when bitrate unknown', () {
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 0),
        3 * 1024 * 1024,
      );
    });

    test('targets ~5s of media at measured bitrate', () {
      // 4 Mbps ≈ 500_000 B/s → 5s ≈ 2.5 MiB
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 500_000),
        2_500_000,
      );
    });

    test('clamps to min 1 MiB', () {
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 50_000),
        1 * 1024 * 1024,
      );
    });

    test('clamps to max 8 MiB', () {
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 5_000_000),
        8 * 1024 * 1024,
      );
    });
  });

  group('iptvProxySkipAbortQueueFloorBytes', () {
    test('fallback when bitrate unknown', () {
      expect(
        iptvProxySkipAbortQueueFloorBytes(estimatedBytesPerSec: 0),
        512 * 1024,
      );
    });

    test('~3s of media at measured bitrate', () {
      expect(
        iptvProxySkipAbortQueueFloorBytes(estimatedBytesPerSec: 500_000),
        1_500_000,
      );
    });

    test('clamps to max 4 MiB', () {
      expect(
        iptvProxySkipAbortQueueFloorBytes(estimatedBytesPerSec: 5_000_000),
        4 * 1024 * 1024,
      );
    });
  });

  group('iptvContinuityProxyMaxQueueBytes', () {
    test('HD uses 12 MiB (covers ≤8 MiB skip)', () {
      expect(
        iptvContinuityProxyMaxQueueBytes(videoHeight: 720, videoBitrate: 0),
        12 * 1024 * 1024,
      );
    });

    test('FHD uses 16 MiB', () {
      expect(
        iptvContinuityProxyMaxQueueBytes(videoHeight: 1080, videoBitrate: 0),
        16 * 1024 * 1024,
      );
    });

    test('UHD uses 20 MiB', () {
      expect(
        iptvContinuityProxyMaxQueueBytes(videoHeight: 2160, videoBitrate: 0),
        20 * 1024 * 1024,
      );
    });

    test('high bitrate promotes to UHD queue', () {
      expect(
        iptvContinuityProxyMaxQueueBytes(
          videoHeight: 1080,
          videoBitrate: 30_000_000,
        ),
        20 * 1024 * 1024,
      );
    });
  });
}
