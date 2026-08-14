import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('builds stream URL with query params', () {
    expect(
      RustLib.instance.buildStremioResourceUrl(
        'https://addon.example/api?token=abc',
        '/stream/movie/tt123.json',
      ),
      'https://addon.example/api/stream/movie/tt123.json?token=abc',
    );
  });

  test('splitAddonUrl', () {
    const url = 'https://addon.example/api/manifest.json?token=abc';
    final parsed =
        jsonDecode(RustLib.instance.splitStremioAddonUrlJson(url))
            as Map<String, dynamic>;
    expect(parsed['base_url'], 'https://addon.example/api');
    expect(parsed['query_params'], 'token=abc');
  });

  test('normalizeManifestUrl handles stremio protocol', () {
    const input = 'stremio://addon.example/manifest.json';
    final rust = RustLib.instance.normalizeStremioManifestUrl(input);
    expect(rust, 'https://addon.example/manifest.json');
  });

  test('buildResourceUrl with query params', () {
    const base = 'https://addon.example/api?token=abc';
    const path = '/catalog/movie/top.json';
    final rust = RustLib.instance.buildStremioResourceUrl(base, path);
    expect(rust, 'https://addon.example/api/catalog/movie/top.json?token=abc');
  });

  test('parseStremioManifestJson via FFI', () {
    const body =
        '{"id":"addon.test","name":"Test Addon","logo":"https://x/icon.png"}';
    final json = RustLib.instance.parseStremioManifestJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed['name'], 'Test Addon');
    expect(parsed['logo'], 'https://x/icon.png');
  });

  test('parseStremioManifestJson accepts object resources', () {
    const body =
        '{"name":"Torrentio","resources":[{"name":"stream","types":["movie","series"]}]}';
    final json = RustLib.instance.parseStremioManifestJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed.containsKey('error'), isFalse);
    final resources = parsed['resources'] as List<dynamic>;
    expect((resources.first as Map)['name'], 'stream');
  });

  test('parseStremioStreamsJson via FFI', () {
    const body =
        '{"streams":[{"url":"https://cdn.example/a.m3u8","title":"1080p"}]}';
    final json = RustLib.instance.parseStremioStreamsJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    final streams = parsed['streams'] as List<dynamic>;
    expect(streams.length, 1);
  });

  test('parseStremioCatalogJson via FFI', () {
    const body =
        '{"metas":[{"id":"tt123","name":"Fight Club","type":"movie"}]}';
    final json = RustLib.instance.parseStremioCatalogJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    final metas = parsed['metas'] as List<dynamic>;
    expect(metas.length, 1);
  });

  test('parseStremioMetaJson via FFI', () {
    const body =
        '{"meta":{"id":"tt123","name":"Fight Club","type":"movie"}}';
    final json = RustLib.instance.parseStremioMetaJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    final meta = parsed['meta'] as Map<String, dynamic>;
    expect(meta['name'], 'Fight Club');
  });

  test('stremioHttpGet rejects invalid URL', () {
    final json = RustLib.instance.stremioHttpGet('not-a-url');
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed.containsKey('error'), isTrue);
  });

  group('classifyStremioStream magnet url', () {
    const desktop = PlaybackProfile.desktop;

    test('HTTP url is direct playable', () {
      final out = classifyStremioStream(
        {'url': 'https://cdn.example/a.m3u8', 'title': '1080p'},
        desktop,
        useDebrid: false,
        debridService: 'None',
      );
      expect(out, isA<StremioPlayable>());
      expect((out as StremioPlayable).streamUrl, 'https://cdn.example/a.m3u8');
    });

    test('HTTP url is direct playable on Android TV', () {
      final out = classifyStremioStream(
        {'url': 'https://cdn.example/a.m3u8', 'title': '1080p'},
        PlaybackProfile.androidTv,
        useDebrid: false,
        debridService: 'None',
      );
      expect(out, isA<StremioPlayable>());
    });

    test('infoHash streams stay visible on Android TV', () {
      expect(
        isStremioStreamVisible(
          {'infoHash': 'c3b7fe335840e824e2ab9131fdeebabc58b126e8'},
          PlaybackProfile.androidTv,
        ),
        isTrue,
      );
    });

    test('magnet url is not direct playable — falls through to resolve', () {
      final out = classifyStremioStream(
        {
          'url':
              'magnet:?xt=urn:btih:c3b7fe335840a824e2ab9131fdeebabc58b126e8',
          'title': 'S01E01',
        },
        desktop,
        useDebrid: false,
        debridService: 'None',
      );
      expect(out, isNull);
    });

    test('infoHash alone falls through to resolve', () {
      final out = classifyStremioStream(
        {'infoHash': 'c3b7fe335840a824e2ab9131fdeebabc58b126e8'},
        desktop,
        useDebrid: false,
        debridService: 'None',
      );
      expect(out, isNull);
    });

    test('buildMagnetFromStremioStream uses magnet url when no infoHash', () {
      const magnet =
          'magnet:?xt=urn:btih:c3b7fe335840a824e2ab9131fdeebabc58b126e8&tr=udp://x';
      expect(
        buildMagnetFromStremioStream({'url': magnet}),
        magnet,
      );
    });

    test('buildMagnetFromStremioStream prefers infoHash over magnet url', () {
      final built = buildMagnetFromStremioStream({
        'infoHash': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'url': 'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'title': 'Show',
      });
      expect(built, startsWith('magnet:?xt=urn:btih:aaaaaaaa'));
      expect(built, contains('dn=Show'));
    });

    test('stremioStreamFileIdx reads fileIdx / mapIdx', () {
      expect(stremioStreamFileIdx({'fileIdx': 6}), 6);
      expect(stremioStreamFileIdx({'fileIdx': '3'}), 3);
      expect(stremioStreamFileIdx({'mapIdx': 1}), 1);
      expect(stremioStreamFileIdx({'title': 'x'}), isNull);
    });
  });

  group('liveStreamRequestHeaders', () {
    test('copies behaviorHints.proxyHeaders.request', () {
      final h = StremioService.liveStreamRequestHeaders({
        'url': 'https://cdn.example/a.m3u8',
        'behaviorHints': {
          'proxyHeaders': {
            'request': {
              'Referer': 'https://addon.example/',
              'Origin': 'https://addon.example',
            },
          },
        },
      });
      expect(h['Referer'], 'https://addon.example/');
      expect(h['Origin'], 'https://addon.example');
    });

    test('recaps.dev gets streamed.pk Referer + browser UA when hints empty', () {
      final h = StremioService.liveStreamRequestHeaders({
        'url': 'https://cdn.recaps.dev/leaf/1/2/index.m3u8',
      });
      expect(h['Referer'], 'https://streamed.pk/');
      expect(h['Origin'], 'https://streamed.pk');
      expect(h['User-Agent'], contains('Chrome/'));
    });

    test('does not override existing Referer on strmd.st', () {
      final h = StremioService.liveStreamRequestHeaders({
        'url': 'https://lb.strmd.st/secure/x/playlist.m3u8',
        'behaviorHints': {
          'proxyHeaders': {
            'request': {'Referer': 'https://custom.example/'},
          },
        },
      });
      expect(h['Referer'], 'https://custom.example/');
      expect(h['User-Agent'], contains('Chrome/'));
    });
  });
}
