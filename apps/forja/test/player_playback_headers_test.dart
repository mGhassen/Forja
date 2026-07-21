import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('normalizePlaybackStreamUrl', () {
    test('strips trailing slash after media extension', () {
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/get_file/x/video.mp4/'),
        'https://cdn.example/get_file/x/video.mp4',
      );
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/a.m3u8///'),
        'https://cdn.example/a.m3u8',
      );
    });

    test('leaves normal urls alone', () {
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/video.mp4'),
        'https://cdn.example/video.mp4',
      );
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/path/'),
        'https://cdn.example/path/',
      );
    });
  });

  group('resolvePlaybackHttpHeaders', () {
    test('always includes browser User-Agent', () {
      final h = resolvePlaybackHttpHeaders(null);
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h['User-Agent'], contains('KHTML, like Gecko'));
    });

    test('preserves extractor Referer and fills Origin', () {
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://fsst.example/',
        'User-Agent': 'CustomUA',
      });
      expect(h['User-Agent'], 'CustomUA');
      expect(h['Referer'], 'https://fsst.example/');
      expect(h['Origin'], 'https://fsst.example');
    });

    test('derives Referer from stream URL when missing', () {
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: 'https://cdn.example/file.mp4',
      );
      expect(h['Referer'], 'https://cdn.example/');
      expect(h['Origin'], 'https://cdn.example');
    });

    test('keeps extractor Referer over CDN-host fallback', () {
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://embed.example/play',
      }, streamUrl: 'https://cdn.other/file.mp4');
      expect(h['Referer'], 'https://embed.example/play');
      expect(h['Origin'], 'https://embed.example');
    });

    test('forwards Cookie and Authorization unchanged', () {
      final h = resolvePlaybackHttpHeaders({
        'Cookie': 'sid=abc',
        'Authorization': 'Bearer tok',
      });
      expect(h['Cookie'], 'sid=abc');
      expect(h['Authorization'], 'Bearer tok');
      expect(h['User-Agent'], contains('Mozilla/5.0'));
    });

    test('canonicalizes lowercase referer/user-agent keys', () {
      final h = resolvePlaybackHttpHeaders({
        'referer': 'https://embed.example/',
        'user-agent': 'Custom/1.0',
        'origin': 'https://embed.example',
      });
      expect(h['Referer'], 'https://embed.example/');
      expect(h['User-Agent'], 'Custom/1.0');
      expect(h['Origin'], 'https://embed.example');
      expect(h.containsKey('referer'), isFalse);
      expect(h.containsKey('user-agent'), isFalse);
      expect(h.containsKey('origin'), isFalse);
    });

    test('strips Referer/Origin for Vidsrc CloudStream /pl/ token streams', () {
      const url =
          'https://sagaciousslumber.site/pl/H4sIAAAAAAAAAw/master.m3u8?token=eyJhbGciOiJIUzI1NiJ9.e30';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://sagaciousslumber.site/',
        'Origin': 'https://sagaciousslumber.site',
        'User-Agent': 'CustomUA',
      }, streamUrl: url);
      expect(h['User-Agent'], 'CustomUA');
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
    });

    test('does not derive Referer from CloudStream /pl/ stream URL', () {
      const url = 'https://sagaciousslumber.site/pl/abc/master.m3u8?token=abc';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
    });

    test('strips Referer/Origin for VidNest MovieBox hakunaymatata CDN', () {
      const url =
          'https://bcdn.hakunaymatata.com/resource/h265/abc.mp4?sign=x&t=1';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://vidnest.fun/',
        'Origin': 'https://vidnest.fun',
        'User-Agent': 'CustomUA',
      }, streamUrl: url);
      expect(h['User-Agent'], 'CustomUA');
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
    });

    test('does not derive Referer from hakunaymatata stream URL', () {
      const url = 'https://sacdn.hakunaymatata.com/dash/x/index_web.mpd?host=y';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
    });

    test('forces kisskh.co Referer for streamingcdn hosts when headers lost', () {
      const url =
          'https://hls08.streamingcdn4.site/12260/Ep2.v673_index0.ts';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['Referer'], 'https://kisskh.co/');
      expect(h['Origin'], 'https://kisskh.co');
    });

    test('forces megaplay Referer for mewstream anime CDN when missing', () {
      const url =
          'https://cdn.mewstream.buzz/anime/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('forces megaplay Referer for nekostream anime CDN when missing', () {
      // Covered by ProviderRuntimeConfig builtins (RFC-039).
      const url =
          'https://9hjkrt.nekostream.site/abc/def/master.m3u8';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('forces megaplay Referer for kotocdn anime CDN when missing', () {
      const url =
          'https://megap.kotocdn.site/abc/def/master.m3u8';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('rewrites nekostream self-Referer to megaplay', () {
      const url =
          'https://9hjkrt.nekostream.site/abc/def/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://9hjkrt.nekostream.site/',
      }, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('rewrites kotocdn self-Referer to megaplay', () {
      const url = 'https://megap.kotocdn.site/abc/def/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://megap.kotocdn.site/',
      }, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('rewrites enma scrape Referer to megaplay for nekostream', () {
      const url =
          'https://9hjkrt.nekostream.site/abc/def/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://www.enma.lol/',
        'Origin': 'https://www.enma.lol',
      }, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('rewrites mewstream self-Referer to megaplay', () {
      const url = 'https://cdn.mewstream.buzz/anime/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://cdn.mewstream.buzz/',
      }, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('keeps megaplay Referer for mewstream', () {
      const url = 'https://cdn.mewstream.buzz/anime/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://megaplay.buzz/',
      }, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
    });

    test('forces allmanga Referer for AllAnime Yt-mp4 CDN', () {
      const url =
          'https://tools.fast4speed.rsvp/media9/videos/x/sub/1?Authorization=1';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['Referer'], 'https://allmanga.to/');
      expect(h['Origin'], 'https://allmanga.to');
    });

    test('forces vidwish Referer for watching.onl anime CDN', () {
      const url =
          'https://fxpy7.watching.onl/anime/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://vidnest.fun/',
      }, streamUrl: url);
      expect(h['Referer'], 'https://vidwish.live/');
      expect(h['Origin'], 'https://vidwish.live');
    });
  });
}
