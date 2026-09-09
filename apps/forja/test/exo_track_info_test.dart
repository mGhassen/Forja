import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';

void main() {
  group('ExoTrackInfo.isAnonymousClosedCaption', () {
    test('CEA-608 without language is anonymous', () {
      const t = ExoTrackInfo(
        id: '3:2:0',
        label: 'CC 1',
        mimeType: 'application/cea-608',
      );
      expect(t.isAnonymousClosedCaption, isTrue);
    });

    test('CEA-608 with language is not anonymous', () {
      const t = ExoTrackInfo(
        id: '3:2:0',
        label: 'English',
        language: 'en',
        mimeType: 'application/cea-608',
      );
      expect(t.isAnonymousClosedCaption, isFalse);
    });

    test('VTT / SubRip are never anonymous CC', () {
      const vtt = ExoTrackInfo(
        id: '3:1:0',
        label: 'English',
        language: 'en',
        mimeType: 'text/vtt',
      );
      const srt = ExoTrackInfo(
        id: '3:1:1',
        label: 'Track 1',
        mimeType: 'application/x-subrip',
      );
      expect(vtt.isAnonymousClosedCaption, isFalse);
      expect(srt.isAnonymousClosedCaption, isFalse);
    });
  });
}
