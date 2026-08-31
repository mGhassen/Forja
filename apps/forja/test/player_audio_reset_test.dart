import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:media_kit/media_kit.dart';

void main() {
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
