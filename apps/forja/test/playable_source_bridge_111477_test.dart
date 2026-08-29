import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/playable_source_bridge.dart';
import 'package:rust/rust.dart';

void main() {
  group('PlayableSourceBridge.requiresProxy', () {
    test('false for service111477 workers.dev (PlayTorrio addon path)', () {
      final playable = [
        PlayableSource(
          url: 'https://strem1o.xn1nazihva.workers.dev/d/abc',
          title: '1080p',
          requiresProxy: false,
          providerId: 'engine:service111477',
        ),
      ];
      expect(
        PlayableSourceBridge.requiresProxy(
          playable,
          0,
          'engine:service111477',
          streamUrl: playable.first.url,
        ),
        isFalse,
      );
    });

    test('true for a.111477.xyz host regardless of provider id', () {
      expect(
        PlayableSourceBridge.requiresProxy(
          null,
          0,
          'videasy',
          streamUrl: 'https://a.111477.xyz/movies/x.mkv',
        ),
        isTrue,
      );
    });

    test('false for unrelated http stream', () {
      expect(
        PlayableSourceBridge.requiresProxy(
          null,
          0,
          'videasy',
          streamUrl: 'https://cdn.example/x.m3u8',
        ),
        isFalse,
      );
    });
  });
}
