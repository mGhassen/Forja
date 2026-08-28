import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  setUp(() {
    ProviderRuntimeConfig.instance.debugSetSnapshot(
      ProviderRuntimeSnapshot.builtins(),
    );
  });

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

    test('keeps CloudFront Cookie on hakunaymatata DASH', () {
      const url =
          'https://sacdn.hakunaymatata.com/dash/x/index_web.mpd';
      final h = resolvePlaybackHttpHeaders({
        'Cookie': 'CloudFront-Policy=abc;CloudFront-Key-Pair-Id=KMHN1LQ1HEUPL',
        'Referer': 'https://vidlink.pro/',
        'User-Agent': 'CustomUA',
      }, streamUrl: url);
      expect(h['User-Agent'], 'CustomUA');
      expect(
        h['Cookie'],
        'CloudFront-Policy=abc;CloudFront-Key-Pair-Id=KMHN1LQ1HEUPL',
      );
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

    test('keeps videodownloader Referer for NetMirror MovieBox CDN', () {
      const url =
          'https://bcdnxw2.hakunaymatata.com/resource/x.mp4?sign=a&t=1';
      final h = resolvePlaybackHttpHeaders(
        {
          'Referer': 'https://videodownloader.site/',
          'User-Agent': 'CustomUA',
        },
        streamUrl: url,
        providerId: 'engine:netmirror',
      );
      expect(h['Referer'], 'https://videodownloader.site/');
      expect(h['User-Agent'], 'CustomUA');
    });

    test('strips Referer/Origin for YouTube googlevideo videoplayback', () {
      const url =
          'https://rr1---sn-abc.googlevideo.com/videoplayback?expire=1&sig=abc';
      final h = resolvePlaybackHttpHeaders(null, streamUrl: url);
      expect(h['User-Agent'], contains('Mozilla/5.0'));
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

    test('strips Referer/Origin for Vidlink mwVault mooncase proxy URLs', () {
      const url =
          'https://noon.mooncase.online/mp/resource/h265/x.mp4?sign=a&t=1'
          '&headers=%7B%22User-Agent%22%3A%22Custom%22%7D'
          '&host=https%3A%2F%2Fbcdn.hakunaymatata.com';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://vidlink.pro/', 'Origin': 'https://vidlink.pro'},
        streamUrl: url,
      );
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
      expect(isMwVaultProxyPlayUrl(url), isTrue);
    });

    test('providerId engine:vidnest does not force vidnest.fun Referer on CDN', () {
      const url = 'https://lamda.example-cdn.net/hls/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'engine:vidnest',
      );
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
    });

    test('providerId vidnest does not force vidnest.fun Referer on CDN', () {
      const url = 'https://lamda.example-cdn.net/hls/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'vidnest',
      );
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h.containsKey('Referer'), isFalse);
      expect(h.containsKey('Origin'), isFalse);
    });

    test('providerId vidnest keeps API Referer when present', () {
      const url = 'https://delta.example-cdn.net/v/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://upstream.example/embed'},
        streamUrl: url,
        providerId: 'vidnest',
      );
      expect(h['Referer'], 'https://upstream.example/embed');
      expect(h['Origin'], 'https://upstream.example');
    });

    test('providerId vidnest:hianime still applies megaplay policy', () {
      const url = 'https://cdn-rotate.example/v/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'vidnest:hianime',
      );
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
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

    test('RFC-044: providerId megaplay forces Referer on unknown CDN', () {
      const url = 'https://brand-new-cdn.example/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'megaplay',
      );
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('RFC-044: providerId bans self-Referer for anime', () {
      const url = 'https://brand-new-cdn.example/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://brand-new-cdn.example/'},
        streamUrl: url,
        providerId: 'megaplay',
      );
      expect(h['Referer'], 'https://megaplay.buzz/');
    });

    test('RFC-044: anime providerId never invents CDN self-Referer', () {
      const url = 'https://cdn.example/x.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'miruro:kiwi',
      );
      // Miruro panel → miruro site origin (not CDN host).
      expect(h['Referer'], 'https://www.miruro.tv/');
      expect(h['Origin'], 'https://www.miruro.tv');
    });

    test('Miruro keeps upstream extract Referer (not forced to miruro.tv)', () {
      const url = 'https://vault-12.owocdn.top/stream/x/uwu.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://kwik.cx/e/abc', 'Origin': 'https://kwik.cx'},
        streamUrl: url,
        providerId: 'miruro:kiwi',
      );
      expect(h['Referer'], 'https://kwik.cx/e/abc');
      expect(h['Origin'], 'https://kwik.cx');
    });

    test('RFC-044: template providerId derives Referer from embed host', () {
      const url = 'https://brand-new-cdn.example/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://brand-new-cdn.example/'},
        streamUrl: url,
        providerId: 'vidfast',
      );
      expect(h['Referer'], 'https://vidfast.vc/');
      expect(h['Origin'], 'https://vidfast.vc');
    });

    test('RFC-044: remote template overlay retargets identity Referer', () {
      ProviderRuntimeConfig.instance.debugSetSnapshot(
        ProviderRuntimeSnapshot.builtins().merged(
          ProviderRuntimeSnapshot.tryParse({
            'schema': 1,
            'templates': {
              'vidrock': {
                'movie': 'https://ops-vidrock.test/movie/{tmdb}',
                'tv': 'https://ops-vidrock.test/tv/{tmdb}/{season}/{episode}',
              },
            },
          })!,
        ),
      );
      const url = 'https://cdn-rotate.example/v.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'vidrock',
      );
      expect(h['Referer'], 'https://ops-vidrock.test/');
      expect(h['Origin'], 'https://ops-vidrock.test');
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

    test('RFC-044: engine:2embed keeps play.xpass.top (not template 2embed.stream)',
        () {
      const url =
          'https://tik.1x2.space/playlist/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://play.xpass.top/'},
        streamUrl: url,
        providerId: 'engine:2embed',
      );
      expect(h['Referer'], 'https://play.xpass.top/');
      expect(h['Origin'], 'https://play.xpass.top');
    });

    test('RFC-044: engine:2embed recovers xpass Referer when headers missing',
        () {
      const url =
          'https://tik.1x2.space/playlist/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'engine:2embed',
      );
      expect(h['Referer'], 'https://play.xpass.top/');
      expect(h['Origin'], 'https://play.xpass.top');
    });

    test('RFC-044: engine:meowtv forces meowtv.ru on 1shows CDN', () {
      const url = 'https://cdn1.1shows.app/e/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://cdn1.1shows.app/'},
        streamUrl: url,
        providerId: 'engine:meowtv',
      );
      expect(h['Referer'], 'https://meowtv.ru/');
      expect(h['Origin'], 'https://meowtv.ru');
    });

    test('RFC-044: providerId vidzee forces player.vidzee.wtf Referer', () {
      const url = 'https://cdn1.1shows.app/e/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://cdn1.1shows.app/'},
        streamUrl: url,
        providerId: 'vidzee',
      );
      expect(h['Referer'], 'https://player.vidzee.wtf/');
      expect(h['Origin'], 'https://player.vidzee.wtf');
    });

    test('RFC-044: providerId videasy forces player.videasy.to Referer', () {
      const url = 'https://cdn-rotate.example/v/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://cdn-rotate.example/'},
        streamUrl: url,
        providerId: 'videasy',
      );
      expect(h['Referer'], 'https://player.videasy.to/');
      expect(h['Origin'], 'https://player.videasy.to');
    });

    test('RFC-044: engine:videasy forces player.videasy.to on peakstorm', () {
      const url =
          'https://moon.peakstorm.top/r2/cdn2/x/1080p/index.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'engine:videasy',
      );
      expect(h['Referer'], 'https://player.videasy.to/');
      expect(h['Origin'], 'https://player.videasy.to');
    });

    test('vidsrcsbs peakstorm uses videasy Referer not vidsrc.sbs', () {
      const url =
          'https://moon.peakstorm.top/vd/abc/index-s1080p-v1-a1.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://player.videasy.to/'},
        streamUrl: url,
        providerId: 'vidsrcsbs',
      );
      expect(h['Referer'], 'https://player.videasy.to/');
      expect(h['Origin'], 'https://player.videasy.to');
    });

    test('engine:vidsrcsbs peakstorm uses videasy Referer', () {
      const url =
          'https://moon.peakstorm.top/vd/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'engine:vidsrcsbs',
      );
      expect(h['Referer'], 'https://player.videasy.to/');
      expect(h['Origin'], 'https://player.videasy.to');
    });

    test('forces megaplay Referer for watching.onl anime CDN', () {
      const url =
          'https://fxpy7.watching.onl/anime/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://vidnest.fun/',
      }, streamUrl: url);
      expect(h['Referer'], 'https://megaplay.buzz/');
      expect(h['Origin'], 'https://megaplay.buzz');
    });

    test('RFC-044: providerId allanime forces allmanga Referer on unknown CDN',
        () {
      const url = 'https://cdn-rotate.example/v/1.mp4';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'allanime:allmanga',
      );
      expect(h['Referer'], 'https://allmanga.to/');
      expect(h['Origin'], 'https://allmanga.to');
    });

    test('RFC-044: providerId allanime bans CDN self-Referer', () {
      const url = 'https://tools.fast4speed.rsvp/media9/videos/x';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://tools.fast4speed.rsvp/'},
        streamUrl: url,
        providerId: 'allanime:yt-mp4',
      );
      expect(h['Referer'], 'https://allmanga.to/');
    });

    test('RFC-044: providerId kisskh forces kisskh Referer on streamingcdn',
        () {
      const url = 'https://streamingcdn123.site/hls/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://streamingcdn123.site/'},
        streamUrl: url,
        providerId: 'kisskh.co',
      );
      expect(h['Referer'], 'https://kisskh.co/');
      expect(h['Origin'], 'https://kisskh.co');
    });

    test('RFC-044: legacy vidwish providerId aliases megaplay Referer', () {
      const url = 'https://fxpy7.watching.onl/anime/abc/master.m3u8';
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: url,
        providerId: 'vidwish',
      );
      expect(h['Referer'], 'https://megaplay.buzz/');
    });
  });
}
