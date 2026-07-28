import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('hlsBitrateForMaxPlaybackHeight', () {
    test('Auto uses soft ceiling', () {
      expect(hlsBitrateForMaxPlaybackHeight(0), kHlsBitrateAutoSoftCeiling);
    });

    test('maps height caps', () {
      expect(hlsBitrateForMaxPlaybackHeight(480), '1500000');
      expect(hlsBitrateForMaxPlaybackHeight(720), '3500000');
      expect(hlsBitrateForMaxPlaybackHeight(1080), '8000000');
      expect(hlsBitrateForMaxPlaybackHeight(1440), '12000000');
      expect(hlsBitrateForMaxPlaybackHeight(2160), 'max');
    });
  });

  group('exoVodCapsForMaxPlaybackHeight', () {
    test('Auto uses soft bitrate only', () {
      final caps = exoVodCapsForMaxPlaybackHeight(0);
      expect(caps.maxVideoHeight, 0);
      expect(caps.maxVideoBitrate, kExoBitrateAutoSoftCeiling);
    });

    test('maps height + bitrate', () {
      expect(exoVodCapsForMaxPlaybackHeight(720).maxVideoHeight, 720);
      expect(exoVodCapsForMaxPlaybackHeight(720).maxVideoBitrate, 3_500_000);
      expect(exoVodCapsForMaxPlaybackHeight(2160).maxVideoHeight, 2160);
      expect(exoVodCapsForMaxPlaybackHeight(2160).maxVideoBitrate, 0);
    });
  });
}
