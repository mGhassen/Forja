import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('audioTrackResyncSeekTarget', () {
    test('stays at zero when already at start', () {
      expect(audioTrackResyncSeekTarget(Duration.zero), Duration.zero);
    });

    test('rewinds to zero when within the nudge window', () {
      expect(
        audioTrackResyncSeekTarget(const Duration(milliseconds: 200)),
        Duration.zero,
      );
      expect(
        audioTrackResyncSeekTarget(kAudioTrackResyncNudge),
        Duration.zero,
      );
    });

    test('rewinds by the nudge when deep in the stream', () {
      const pos = Duration(seconds: 42);
      expect(
        audioTrackResyncSeekTarget(pos),
        pos - kAudioTrackResyncNudge,
      );
      expect(audioTrackResyncSeekTarget(pos) < pos, isTrue);
    });

    test('nudge stays under peakstorm remount seek delta', () {
      expect(
        kAudioTrackResyncNudge < kPeakstormRemountSeekMinDelta,
        isTrue,
      );
    });
  });

  group('pickBestAudioTrack', () {
    test('prefers lowest aid when scores tie', () {
      final tracks = [
        AudioTrack('3', null, 'ja'),
        AudioTrack('1', null, 'ja'),
        AudioTrack('2', null, 'ja'),
      ];
      expect(
        pickBestAudioTrack(
          audioTracks: tracks,
          preferredAudioLang: 'None',
          avoidUnsupportedAudio: false,
        )?.id,
        '1',
      );
    });
  });

  group('isStalePlayerAudioSelection', () {
    test('false for auto/no', () {
      final tracks = [AudioTrack('1', null, 'en')];
      expect(isStalePlayerAudioSelection(AudioTrack.auto(), tracks), isFalse);
      expect(isStalePlayerAudioSelection(AudioTrack.no(), tracks), isFalse);
    });

    test('true when aid is missing from the new mux list', () {
      final tracks = [AudioTrack('1', null, 'en')];
      expect(
        isStalePlayerAudioSelection(AudioTrack('3', null, 'ja'), tracks),
        isTrue,
      );
    });

    test('false when current id exists in tracks', () {
      final tracks = [
        AudioTrack('1', null, 'en'),
        AudioTrack('2', null, 'ja'),
      ];
      expect(
        isStalePlayerAudioSelection(AudioTrack('2', null, 'ja'), tracks),
        isFalse,
      );
    });
  });
}
