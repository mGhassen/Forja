import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';

void main() {
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
