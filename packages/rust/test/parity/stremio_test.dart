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
}
