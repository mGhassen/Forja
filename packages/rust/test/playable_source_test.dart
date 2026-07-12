import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/models/playable_source.dart';

void main() {
  group('PlayableSource JSON', () {
    test('fromJson/toJson round-trip', () {
      const source = PlayableSource(
        url: 'https://cdn/a.m3u8',
        title: '1080p',
        container: 'hls',
        providerId: 'videasy',
        providerRank: 2,
        requiresProxy: false,
      );
      final restored = PlayableSource.fromJson(source.toJson());
      expect(restored.url, source.url);
      expect(restored.title, source.title);
      expect(restored.providerId, source.providerId);
    });

    test('toStreamSource maps container to legacy type', () {
      const source = PlayableSource(
        url: 'https://cdn/a.m3u8',
        title: '1080p',
        container: 'hls',
      );
      final legacy = source.toStreamSource();
      expect(legacy.type, 'hls');
      expect(legacy.url, source.url);
    });
  });

  group('DevicePlaybackCapabilities', () {
    test('constrained profile defaults', () {
      const caps = DevicePlaybackCapabilities.constrained;
      expect(caps.hevc, false);
      expect(caps.maxHeight, 1080);
      expect(caps.isLowPower, true);
    });

    test('fromJson round-trip', () {
      const caps = DevicePlaybackCapabilities(
        maxHeight: 1080,
        hevc: true,
        av1: false,
      );
      final restored = DevicePlaybackCapabilities.fromJson(caps.toJson());
      expect(restored.maxHeight, 1080);
      expect(restored.hevc, true);
    });
  });
}
