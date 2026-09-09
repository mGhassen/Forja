import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv_proxy_reconnect_skip.dart';

void main() {
  group('iptvProxyReconnectSkipBytes', () {
    test('fallback when bitrate unknown', () {
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 0),
        2 * 1024 * 1024,
      );
    });

    test('targets ~2.5s of media at measured bitrate', () {
      // 4 Mbps ≈ 500_000 B/s → 2.5s ≈ 1.25 MiB
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 500_000),
        1_250_000,
      );
    });

    test('clamps to min 768 KiB', () {
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 50_000),
        768 * 1024,
      );
    });

    test('clamps to max 4 MiB', () {
      expect(
        iptvProxyReconnectSkipBytes(estimatedBytesPerSec: 5_000_000),
        4 * 1024 * 1024,
      );
    });
  });

  group('iptvProxyMinSkipBytes', () {
    test('fallback when bitrate unknown', () {
      expect(iptvProxyMinSkipBytes(estimatedBytesPerSec: 0), 1024 * 1024);
    });

    test('~1.5s of media', () {
      expect(iptvProxyMinSkipBytes(estimatedBytesPerSec: 500_000), 750_000);
    });
  });

  group('iptvProxyShouldAbortSkip', () {
    test('never aborts at skipped=0 even with empty queue', () {
      expect(
        iptvProxyShouldAbortSkip(
          skippedBytes: 0,
          minSkipBytes: 1024 * 1024,
          queuedBytes: 0,
          abortFloorBytes: 512 * 1024,
          elapsedMs: 0,
        ),
        isFalse,
      );
    });

    test('aborts after min skip when queue below floor', () {
      expect(
        iptvProxyShouldAbortSkip(
          skippedBytes: 1024 * 1024,
          minSkipBytes: 1024 * 1024,
          queuedBytes: 100,
          abortFloorBytes: 512 * 1024,
          elapsedMs: 200,
        ),
        isTrue,
      );
    });

    test('aborts on wall-clock max even with fat queue', () {
      expect(
        iptvProxyShouldAbortSkip(
          skippedBytes: 100,
          minSkipBytes: 1024 * 1024,
          queuedBytes: 8 * 1024 * 1024,
          abortFloorBytes: 512 * 1024,
          elapsedMs: 1200,
        ),
        isTrue,
      );
    });

    test('continues skip while under min and under wall clock', () {
      expect(
        iptvProxyShouldAbortSkip(
          skippedBytes: 100 * 1024,
          minSkipBytes: 1024 * 1024,
          queuedBytes: 0,
          abortFloorBytes: 512 * 1024,
          elapsedMs: 400,
        ),
        isFalse,
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

    test('~2s of media at measured bitrate', () {
      expect(
        iptvProxySkipAbortQueueFloorBytes(estimatedBytesPerSec: 500_000),
        1_000_000,
      );
    });

    test('clamps to max 2 MiB', () {
      expect(
        iptvProxySkipAbortQueueFloorBytes(estimatedBytesPerSec: 5_000_000),
        2 * 1024 * 1024,
      );
    });
  });

  group('iptvContinuityProxyMaxQueueBytes', () {
    test('HD uses 12 MiB (covers ≤4 MiB skip)', () {
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
