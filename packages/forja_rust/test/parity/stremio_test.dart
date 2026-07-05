import '../helpers/rust_engine.dart';
import 'package:forja_api/api/stremio_service.dart';
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
    final dart = StremioService.debugSplitAddonUrl(url);
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
    final parts = StremioService.debugSplitAddonUrl(base);
    final dart = parts.queryParams != null
        ? '${parts.baseUrl}$path?${parts.queryParams}'
        : '${parts.baseUrl}$path';
    expect(rust, dart);
  });
}
