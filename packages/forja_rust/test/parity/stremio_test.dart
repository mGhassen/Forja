import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/src/dart_fallback.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('builds stream URL with query params', () {
    expect(
      ForjaRust.instance.buildStremioResourceUrl(
        'https://addon.example/api?token=abc',
        '/stream/movie/tt123.json',
      ),
      'https://addon.example/api/stream/movie/tt123.json?token=abc',
    );
  });

  test('splitAddonUrl parity', () {
    const url = 'https://addon.example/api/manifest.json?token=abc';
    final rust = ForjaRust.instance.splitStremioAddonUrlJson(url);
    final dart = StremioDartParse.splitAddonUrl(url);
    expect(rust, contains('"base_url":"https://addon.example/api"'));
    expect(dart.baseUrl, 'https://addon.example/api');
    expect(dart.queryParams, 'token=abc');
  });

  test('normalizeManifestUrl handles stremio protocol', () {
    const input = 'stremio://addon.example/manifest.json';
    final rust = ForjaRust.instance.normalizeStremioManifestUrl(input);
    expect(rust, 'https://addon.example/manifest.json');
  });

  test('buildResourceUrl parity with StremioService logic', () {
    const base = 'https://addon.example/api?token=abc';
    const path = '/catalog/movie/top.json';
    final rust = ForjaRust.instance.buildStremioResourceUrl(base, path);
    final parts = StremioDartParse.splitAddonUrl(base);
    final dart = parts.queryParams != null
        ? '${parts.baseUrl}$path?${parts.queryParams}'
        : '${parts.baseUrl}$path';
    expect(rust, dart);
  });

  test('parseStremioManifestJson via FFI', () {
    const body = '{"id":"addon.test","name":"Test Addon","logo":"https://x/icon.png"}';
    final json = ForjaRust.instance.parseStremioManifestJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed['name'], 'Test Addon');
    expect(parsed['logo'], 'https://x/icon.png');
  });

  test('parseStremioStreamsJson via FFI', () {
    const body = '{"streams":[{"url":"https://cdn.example/a.m3u8","title":"1080p"}]}';
    final json = ForjaRust.instance.parseStremioStreamsJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    final streams = parsed['streams'] as List<dynamic>;
    expect(streams.length, 1);
  });

  test('parseStremioCatalogJson via FFI', () {
    const body = '{"metas":[{"id":"tt123","name":"Fight Club","type":"movie"}]}';
    final json = ForjaRust.instance.parseStremioCatalogJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    final metas = parsed['metas'] as List<dynamic>;
    expect(metas.length, 1);
  });

  test('parseStremioMetaJson via FFI', () {
    const body = '{"meta":{"id":"tt123","name":"Fight Club","type":"movie"}}';
    final json = ForjaRust.instance.parseStremioMetaJson(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    final meta = parsed['meta'] as Map<String, dynamic>;
    expect(meta['name'], 'Fight Club');
  });

  test('stremioHttpGet rejects invalid URL', () {
    final json = ForjaRust.instance.stremioHttpGet('not-a-url');
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed.containsKey('error'), isTrue);
  });
}
