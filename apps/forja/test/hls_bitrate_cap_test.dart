import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

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

  group('preferHlsVariantUnderHeight', () {
    final master = 'https://cdn.example/master.m3u8';
    final qualities = [
      const HlsQuality(
        label: '2160p',
        url: 'https://cdn.example/2160.m3u8',
        height: 2160,
      ),
      const HlsQuality(
        label: '1080p',
        url: 'https://cdn.example/1080.m3u8',
        height: 1080,
      ),
      const HlsQuality(
        label: '720p',
        url: 'https://cdn.example/720.m3u8',
        height: 720,
      ),
      HlsQuality(
        label: 'Auto',
        url: master,
        isAuto: true,
      ),
    ];

    test('picks highest under cap', () async {
      final url = await preferHlsVariantUnderHeight(
        master,
        maxHeight: 1080,
        qualitiesOverride: qualities,
      );
      expect(url, 'https://cdn.example/1080.m3u8');
    });

    test('falls to lowest when all above cap', () async {
      final url = await preferHlsVariantUnderHeight(
        master,
        maxHeight: 480,
        qualitiesOverride: qualities,
      );
      expect(url, 'https://cdn.example/720.m3u8');
    });
  });

  group('isKissKhProviderId', () {
    test('matches kisskh family', () {
      expect(isKissKhProviderId('kisskh.nl'), isTrue);
      expect(isKissKhProviderId('kisskh'), isTrue);
      expect(isKissKhProviderId('vidsrc'), isFalse);
    });
  });
}
