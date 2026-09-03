import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  PlayerState state({required int posMs, required int durMs}) {
    return PlayerState().copyWith(
      position: Duration(milliseconds: posMs),
      duration: Duration(milliseconds: durMs),
    );
  }

  group('isNaturalPlaybackEnd', () {
    test('false for tiny probe durations (torrent false completed)', () {
      // dur=500ms + pos=0 → old formula `0 >= 500-1000` was true.
      expect(
        isNaturalPlaybackEnd(state(posMs: 0, durMs: 500)),
        isFalse,
      );
      expect(
        isNaturalPlaybackEnd(state(posMs: 0, durMs: 30_000)),
        isFalse,
      );
    });

    test('false at position zero even with long duration', () {
      expect(
        isNaturalPlaybackEnd(state(posMs: 0, durMs: 3_600_000)),
        isFalse,
      );
    });

    test(
      'true at position zero after mid-watch + grace (keep-open EOF reset)',
      () {
        expect(
          isNaturalPlaybackEnd(
            state(posMs: 0, durMs: 3_600_000),
            confirmedFor: const Duration(seconds: 171),
            hadMidPlayback: true,
          ),
          isTrue,
        );
      },
    );

    test('false at position zero within grace even with mid flag', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 0, durMs: 3_600_000),
          confirmedFor: const Duration(seconds: 3),
          hadMidPlayback: true,
        ),
        isFalse,
      );
    });

    test('true near real end of a long title after enough confirmed time', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_599_500, durMs: 3_600_000),
          confirmedFor: const Duration(minutes: 50),
          hadMidPlayback: true,
        ),
        isTrue,
      );
    });

    test('false when EOF arrives seconds after confirm (torrent early EOF)', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_938_142, durMs: 3_938_142),
          confirmedFor: const Duration(seconds: 3),
        ),
        isFalse,
      );
    });

    test('false when stuck at EOF without mid-episode playback even after grace', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_938_142, durMs: 3_938_142),
          confirmedFor: const Duration(minutes: 2),
          hadMidPlayback: false,
        ),
        isFalse,
      );
    });

    test('true when mid-watched session age is used after late reconfirm', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_599_500, durMs: 3_600_000),
          confirmedFor: confirmedPlaybackAge(
            openConfirmedAt: DateTime(2026, 7, 17, 0, 20, 0),
            sessionFirstConfirmedAt: DateTime(2026, 7, 17, 0, 0, 0),
            hadMidPlayback: true,
            now: DateTime(2026, 7, 17, 0, 20, 5),
          ),
          hadMidPlayback: true,
        ),
        isTrue,
      );
    });
  });

  group('confirmedPlaybackAge', () {
    test('uses open confirm when mid was not watched', () {
      final open = DateTime(2026, 7, 17, 0, 20, 0);
      final session = DateTime(2026, 7, 17, 0, 0, 0);
      expect(
        confirmedPlaybackAge(
          openConfirmedAt: open,
          sessionFirstConfirmedAt: session,
          hadMidPlayback: false,
          now: open.add(const Duration(seconds: 5)),
        ),
        const Duration(seconds: 5),
      );
    });

    test('uses session first confirm when mid was watched', () {
      final open = DateTime(2026, 7, 17, 0, 20, 0);
      final session = DateTime(2026, 7, 17, 0, 0, 0);
      expect(
        confirmedPlaybackAge(
          openConfirmedAt: open,
          sessionFirstConfirmedAt: session,
          hadMidPlayback: true,
          now: open.add(const Duration(seconds: 5)),
        ),
        const Duration(minutes: 20, seconds: 5),
      );
    });
  });

  group('shouldPersistWatchProgress', () {
    final confirmed = DateTime(2026, 7, 16, 2, 57, 50);

    test('skips near-end progress within grace window', () {
      expect(
        shouldPersistWatchProgress(
          positionMs: 3_938_142,
          durationMs: 3_938_142,
          confirmedAt: confirmed,
          now: confirmed.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('allows mid-episode progress within grace window', () {
      expect(
        shouldPersistWatchProgress(
          positionMs: 120_000,
          durationMs: 3_600_000,
          confirmedAt: confirmed,
          now: confirmed.add(const Duration(seconds: 20)),
        ),
        isTrue,
      );
    });

    test('allows near-end progress after grace window', () {
      expect(
        shouldPersistWatchProgress(
          positionMs: 3_590_000,
          durationMs: 3_600_000,
          confirmedAt: confirmed,
          now: confirmed.add(const Duration(minutes: 55)),
        ),
        isTrue,
      );
    });

    test('allows near-end after late reconfirm when mid session is old enough', () {
      final session = DateTime(2026, 7, 17, 0, 0, 0);
      final open = DateTime(2026, 7, 17, 0, 20, 0);
      expect(
        shouldPersistWatchProgress(
          positionMs: 1_456_997,
          durationMs: 1_456_997,
          confirmedAt: open,
          sessionFirstConfirmedAt: session,
          hadMidPlayback: true,
          now: open.add(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });
  });

  group('shouldSuppressEarlyEofSeekBarPosition', () {
    test('suppresses near-end jump within grace without mid', () {
      expect(
        shouldSuppressEarlyEofSeekBarPosition(
          positionMs: 1_422_004,
          durationMs: 1_422_004,
          confirmedFor: const Duration(seconds: 17),
          hadMidPlayback: false,
        ),
        isTrue,
      );
    });

    test('allows near-end after mid watch', () {
      expect(
        shouldSuppressEarlyEofSeekBarPosition(
          positionMs: 1_422_004,
          durationMs: 1_422_004,
          confirmedFor: const Duration(minutes: 20),
          hadMidPlayback: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldAcceptNaturalPlaybackEnd', () {
    test('rejects dead CDN open after prior session mid', () {
      expect(
        shouldAcceptNaturalPlaybackEnd(
          state: state(posMs: 3_600_000, durMs: 3_600_000),
          openConfirmedFor: const Duration(seconds: 3),
          openHadMidPlayback: false,
          sessionHadMidPlayback: true,
          uiPosition: const Duration(minutes: 60),
          uiDuration: const Duration(minutes: 60),
        ),
        isFalse,
      );
    });

    test('accepts same-open finish after mid + grace', () {
      expect(
        shouldAcceptNaturalPlaybackEnd(
          state: state(posMs: 3_599_500, durMs: 3_600_000),
          openConfirmedFor: const Duration(minutes: 20),
          openHadMidPlayback: true,
          sessionHadMidPlayback: true,
          uiPosition: const Duration(milliseconds: 3_599_500),
          uiDuration: const Duration(milliseconds: 3_600_000),
        ),
        isTrue,
      );
    });

    test('accepts credits re-open only after open grace + UI at EOF', () {
      expect(
        shouldAcceptNaturalPlaybackEnd(
          state: state(posMs: 3_599_500, durMs: 3_600_000),
          openConfirmedFor: const Duration(seconds: 50),
          openHadMidPlayback: false,
          sessionHadMidPlayback: true,
          uiPosition: const Duration(milliseconds: 3_599_500),
          uiDuration: const Duration(milliseconds: 3_600_000),
        ),
        isTrue,
      );
    });
  });

  group('cacheTimeForSeekBarBuffer', () {
    test('drops absolute torrent PTS far ahead of playhead', () {
      expect(
        cacheTimeForSeekBarBuffer(
          position: const Duration(minutes: 49),
          cacheTime: const Duration(hours: 1, minutes: 18),
          localTorrent: true,
        ),
        Duration.zero,
      );
    });

    test('keeps near playhead cache and non-torrent absolute buffer', () {
      expect(
        cacheTimeForSeekBarBuffer(
          position: const Duration(minutes: 49),
          cacheTime: const Duration(minutes: 49, seconds: 30),
          localTorrent: true,
        ),
        const Duration(minutes: 49, seconds: 30),
      );
      expect(
        cacheTimeForSeekBarBuffer(
          position: const Duration(minutes: 10),
          cacheTime: const Duration(hours: 1),
          localTorrent: false,
        ),
        const Duration(hours: 1),
      );
    });
  });

  group('localTorrentSeekNeedsRemount', () {
    test('true when scrubbing back more than 1s', () {
      expect(
        localTorrentSeekNeedsRemount(
          previous: const Duration(minutes: 49),
          target: const Duration(minutes: 30),
        ),
        isTrue,
      );
    });

    test('true when scrubbing forward more than 1s', () {
      expect(
        localTorrentSeekNeedsRemount(
          previous: const Duration(minutes: 30),
          target: const Duration(minutes: 49),
        ),
        isTrue,
      );
    });

    test('false for tiny nudge', () {
      expect(
        localTorrentSeekNeedsRemount(
          previous: const Duration(seconds: 100),
          target: const Duration(seconds: 99, milliseconds: 500),
        ),
        isFalse,
      );
    });
  });

  group('torrentSeekRemountSettled', () {
    PlayerState stubState({
      Duration position = Duration.zero,
      bool playing = false,
      bool buffering = false,
      int w = 1920,
      int h = 1080,
    }) {
      return PlayerState(
        position: position,
        playing: playing,
        buffering: buffering,
        videoParams: VideoParams(w: w, h: h),
      );
    }

    test('rejects false success at 0:00 when target is far ahead', () {
      expect(
        torrentSeekRemountSettled(
          stubState(position: Duration.zero, playing: true),
          const Duration(minutes: 45),
        ),
        isFalse,
      );
    });

    test('accepts buffering near target', () {
      expect(
        torrentSeekRemountSettled(
          stubState(
            position: const Duration(minutes: 44, seconds: 55),
            buffering: true,
          ),
          const Duration(minutes: 45),
        ),
        isTrue,
      );
    });

    test('rejects position still far from target', () {
      expect(
        torrentSeekRemountSettled(
          stubState(
            position: const Duration(minutes: 10),
            playing: true,
          ),
          const Duration(minutes: 45),
        ),
        isFalse,
      );
    });
  });

  group('shouldPinSeekBarAtEof', () {
    test('false when UI already scrubbed away', () {
      expect(
        shouldPinSeekBarAtEof(
          uiPosition: const Duration(minutes: 10),
          duration: const Duration(minutes: 24),
        ),
        isFalse,
      );
    });

    test('true when UI still at end', () {
      expect(
        shouldPinSeekBarAtEof(
          uiPosition: const Duration(minutes: 24),
          duration: const Duration(minutes: 24),
        ),
        isTrue,
      );
    });
  });

  group('shouldIgnoreStaleEofPosition', () {
    test('ignores stale EOF report after scrub-away', () {
      final scrubbed = DateTime(2026, 7, 17, 15, 0, 0);
      expect(
        shouldIgnoreStaleEofPosition(
          reported: const Duration(minutes: 24),
          duration: const Duration(minutes: 24),
          uiPosition: const Duration(minutes: 10),
          seekAwayFromEofAt: scrubbed,
          now: scrubbed.add(const Duration(milliseconds: 200)),
        ),
        isTrue,
      );
    });

    test('stops ignoring after grace', () {
      final scrubbed = DateTime(2026, 7, 17, 15, 0, 0);
      expect(
        shouldIgnoreStaleEofPosition(
          reported: const Duration(minutes: 24),
          duration: const Duration(minutes: 24),
          uiPosition: const Duration(minutes: 10),
          seekAwayFromEofAt: scrubbed,
          now: scrubbed.add(const Duration(seconds: 3)),
        ),
        isFalse,
      );
    });
  });

  group('sourceRequiresVideoDecode', () {
    test('requires decode for local torrent stream URLs', () {
      expect(
        sourceRequiresVideoDecode(
          'http://127.0.0.1:52788/torrents/0/stream/0/ep.mp4',
        ),
        isTrue,
      );
      expect(
        sourceRequiresVideoDecode('https://cdn.example/video.mp4'),
        isFalse,
      );
    });

    test('vixsrc extensionless /playlist/ requires decode even when typed mp4',
        () {
      const url =
          'https://vixsrc.to/playlist/174559?b=1&token=abc&expires=1&h=1';
      expect(urlLooksLikeHls(url), isTrue);
      expect(sourceRequiresVideoDecode(url, type: 'mp4'), isTrue);
      expect(
        sourceRequiresSeekableDurationBeforeConfirm(url, type: 'mp4'),
        isFalse,
      );
    });

    test('extensionless /playlist/ HLS is proxied, .m3u8 is not', () {
      const vix =
          'https://vixsrc.to/playlist/174559?b=1&token=abc&expires=1&h=1';
      expect(shouldProxyExtensionlessHls(vix), isTrue);
      expect(
        shouldProxyExtensionlessHls('https://cdn.example/master.m3u8'),
        isFalse,
      );
      expect(
        shouldProxyExtensionlessHls(
          'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent(vix)}',
        ),
        isFalse,
      );
    });
  });

  group('sourceRequiresSeekableDurationBeforeConfirm', () {
    test('HLS that requires decode does not hard-gate on duration', () {
      expect(
        sourceRequiresSeekableDurationBeforeConfirm(
          'https://cdn.example/playlist.m3u8?token=1',
          type: 'mp4',
        ),
        isFalse,
      );
      expect(
        sourceRequiresSeekableDurationBeforeConfirm(
          'https://cdn.example/playlist.m3u8',
          type: 'hls',
        ),
        isFalse,
      );
    });

    test('progressive mp4 still requires duration before confirm', () {
      expect(
        sourceRequiresSeekableDurationBeforeConfirm(
          'https://cdn.example/video.mp4',
          type: 'mp4',
        ),
        isTrue,
      );
    });
  });

  group('isOpenReadyForStream', () {
    PlayerState state({
      int? videoW,
      int? videoH,
      int bufferMs = 0,
      int durationMs = 0,
      int positionMs = 0,
      bool playing = false,
      double bufferingPercentage = 0,
    }) {
      return PlayerState().copyWith(
        videoParams: VideoParams(w: videoW, h: videoH),
        buffer: Duration(milliseconds: bufferMs),
        duration: Duration(milliseconds: durationMs),
        position: Duration(milliseconds: positionMs),
        playing: playing,
        bufferingPercentage: bufferingPercentage,
      );
    }

    test('local torrent ignores buffer/duration without decoded video', () {
      expect(
        isOpenReadyForStream(
          state(bufferMs: 5000, durationMs: 3_600_000, playing: true),
          localTorrent: true,
        ),
        isFalse,
      );
    });

    test('local torrent ready only after decoded video', () {
      expect(
        isOpenReadyForStream(
          state(videoW: 1920, videoH: 1080),
          localTorrent: true,
        ),
        isTrue,
      );
    });

    test('non-torrent still treats buffer as ready', () {
      expect(
        isOpenReadyForStream(state(bufferMs: 1000), localTorrent: false),
        isTrue,
      );
    });
  });
}
