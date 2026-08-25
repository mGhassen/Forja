import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/network_playback_recovery.dart';

void main() {
  group('isLikelyNetworkPlaybackError', () {
    test('matches common offline / socket fatals', () {
      expect(
        isLikelyNetworkPlaybackError(
          'Failed to open https://cdn.example/master.m3u8',
        ),
        isTrue,
      );
      expect(
        isLikelyNetworkPlaybackError('tcp: Failed to resolve host'),
        isTrue,
      );
      expect(
        isLikelyNetworkPlaybackError('Connection reset by peer'),
        isTrue,
      );
      expect(
        isLikelyNetworkPlaybackError('HTTP error 502 Bad Gateway'),
        isTrue,
      );
      expect(
        isLikelyNetworkPlaybackError('Network is unreachable'),
        isTrue,
      );
    });

    test('ignores decoder / subtitle noise', () {
      expect(
        isLikelyNetworkPlaybackError('Failed to initialize video decoder'),
        isFalse,
      );
      expect(
        isLikelyNetworkPlaybackError('Could not open subtitle file'),
        isFalse,
      );
      expect(isLikelyNetworkPlaybackError('hwdec: codec failed'), isFalse);
    });
  });

  group('attemptNetworkPlaybackRemount', () {
    test('retries remount and succeeds on later attempt', () async {
      var calls = 0;
      final ok = await attemptNetworkPlaybackRemount(
        maxAttempts: 3,
        onlineTimeout: const Duration(milliseconds: 50),
        betweenAttempts: const Duration(milliseconds: 5),
        remount: () async {
          calls++;
          return calls >= 2;
        },
      );
      expect(ok, isTrue);
      expect(calls, 2);
    });

    test('stops when cancelled', () async {
      var calls = 0;
      final ok = await attemptNetworkPlaybackRemount(
        maxAttempts: 5,
        onlineTimeout: const Duration(milliseconds: 50),
        betweenAttempts: const Duration(milliseconds: 5),
        isCancelled: () => calls >= 1,
        remount: () async {
          calls++;
          return false;
        },
      );
      expect(ok, isFalse);
      expect(calls, 1);
    });
  });
}
