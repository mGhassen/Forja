import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  const roots = ['/data/user/0/app/Download/Forja'];

  group('isPlayableStreamUrl', () {
    test('http and https on any host', () {
      expect(isPlayableStreamUrl('http://cdn.example/a.m3u8'), isTrue);
      expect(isPlayableStreamUrl('https://cdn.example/a.mp4?token=x'), isTrue);
      expect(isPlayableStreamUrl('http://192.168.1.20:8096/stream'), isTrue);
    });

    test('loopback proxy with any port', () {
      expect(
        isPlayableStreamUrl('http://127.0.0.1:43123/hls-proxy?url=x'),
        isTrue,
      );
      expect(
        isPlayableStreamUrl('http://localhost:9/torrents/1/stream/0'),
        isTrue,
      );
      expect(isLoopbackStreamUrl('http://127.0.0.1:43123/x'), isTrue);
      expect(isLoopbackStreamUrl('http://cdn.example/x'), isFalse);
    });

    test('file under a registered root is playable', () {
      expect(
        isPlayableStreamUrl(
          'file:///data/user/0/app/Download/Forja/Show/ep1.mp4',
          allowedFileRoots: roots,
        ),
        isTrue,
      );
    });

    test('file elsewhere, traversal, and the root itself are refused', () {
      expect(
        isPlayableStreamUrl('file:///etc/passwd', allowedFileRoots: roots),
        isFalse,
      );
      expect(
        isPlayableStreamUrl(
          'file:///data/user/0/app/Download/Forja/../../shared_prefs/x.xml',
          allowedFileRoots: roots,
        ),
        isFalse,
      );
      expect(
        isPlayableStreamUrl(
          'file:///data/user/0/app/Download/Forja',
          allowedFileRoots: roots,
        ),
        isFalse,
      );
      expect(
        isPlayableStreamUrl(
          'file:///data/user/0/app/Download/ForjaOther/x.mp4',
          allowedFileRoots: roots,
        ),
        isFalse,
      );
    });

    test('no registered roots → no file stream', () {
      expect(
        isPlayableStreamUrl(
          'file:///anything/x.mp4',
          allowedFileRoots: const [],
        ),
        isFalse,
      );
    });

    test('content, javascript, intent, data, rtmp, bare paths refused', () {
      for (final u in [
        'content://media/external/video/1',
        'javascript:alert(1)',
        'intent://play#Intent;scheme=http;end',
        'data:video/mp4;base64,AAAA',
        'rtmp://live.example/app/key',
        'rtsp://cam.example/live',
        '/sdcard/x.mp4',
        'ftp://x/y.mp4',
        '',
        null,
      ]) {
        expect(
          isPlayableStreamUrl(u, allowedFileRoots: roots),
          isFalse,
          reason: '$u',
        );
      }
    });

    test('assertPlayableStreamUrl throws the typed error', () {
      expect(
        () => assertPlayableStreamUrl('content://x/y'),
        throwsA(
          isA<UnsupportedStreamAddressException>().having(
            (e) => e.message,
            'message',
            'Unsupported stream address',
          ),
        ),
      );
    });

    test('PlayableStreamFileRoots feeds the default roots', () {
      PlayableStreamFileRoots.clear();
      expect(isPlayableStreamUrl('file:///tmp/dl/x.mp4'), isFalse);
      PlayableStreamFileRoots.add('/tmp/dl/');
      expect(isPlayableStreamUrl('file:///tmp/dl/x.mp4'), isTrue);
      PlayableStreamFileRoots.clear();
    });
  });

  group('classifyStremioStream', () {
    test('rejected address becomes an unsupported failure, not playable', () {
      final out = classifyStremioStream({
        'url': 'content://media/external/video/1',
        'name': 'row',
      }, PlaybackProfile.desktop);
      expect(out, isA<StremioResolveFailure>());
      expect(
        (out as StremioResolveFailure).error,
        StremioPlaybackError.unsupported,
      );
    });

    test('https row stays playable', () {
      final out = classifyStremioStream({
        'url': 'https://cdn.example/a.m3u8',
      }, PlaybackProfile.desktop);
      expect(out, isA<StremioPlayable>());
    });
  });
}
