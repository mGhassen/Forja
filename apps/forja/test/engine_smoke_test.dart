import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_test_init.dart';
import 'helpers/torrent_e2e.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initEngineForTests();
  });

  setUp(() {
    if (RustLib.isInitialized) {
      RustLib.instance.torrentEngineStop();
      RustLib.instance.torrentStop();
    }
  });

  tearDown(() {
    if (RustLib.isInitialized) {
      RustLib.instance.torrentEngineStop();
      RustLib.instance.torrentStop();
    }
  });

  test('Engine loads native library', () {
    expect(
      Engine.isReady,
      isTrue,
      reason: 'Run ./scripts/build_rust.sh before engine smoke tests',
    );
    expect(RustLib.instance.version, isNotEmpty);
  });

  testWidgets('flutter binding boots', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });

  test('M3U parse returns channels', () async {
    const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="ch1" tvg-name="News" tvg-logo="http://logo.example/icon.png" group-title="News",News HD
http://stream.example/live
''';
    final channels = await Engine.parseM3uChannels(content);
    expect(channels, hasLength(1));
    expect(channels.first['name'], 'News HD');
    expect(channels.first['group'], 'News');
  });

  test('IPTV Xtream categories via Rust FFI', () {
    expect(RustLib.isInitialized, isTrue);
    const json = '[{"category_id":"1","category_name":"Sports"}]';
    final rows =
        jsonDecode(RustLib.instance.parseXtreamCategoriesJson(json)) as List;
    expect(rows.first['name'], 'Sports');
  });

  test('legacy embed ProviderRegistry is empty', () {
    expect(ProviderRegistry.all, isEmpty);
    expect(ProviderRegistry.byId('vidlink'), isNull);
  });

  test('torrent peer limit + engine restart', () async {
    final svc = TorrentStreamService();
    expect(await svc.start(), isTrue);
    await svc.applyConnectionsLimit(75);
    expect(svc.state, EngineState.ready);
  });

  test('torrent engine starts on loopback', () {
    final port = RustLib.instance.torrentEngineStart(0);
    expect(port, greaterThan(0));
    expect(RustLib.instance.torrentEnginePort(), port);
  });

  test('invalid magnet rejected', () {
    RustLib.instance.torrentEngineStart(0);
    expect(RustLib.instance.torrentStart('not-a-magnet'), isFalse);
  });

  test('Stremio resource URL via Rust FFI', () {
    expect(RustLib.isInitialized, isTrue);
    final url = RustLib.instance.buildStremioResourceUrl(
      'https://addon.example/api?token=abc',
      '/stream/movie/tt123.json',
    );
    expect(url, 'https://addon.example/api/stream/movie/tt123.json?token=abc');
  });

  test('Stremio manifest JSON via Rust FFI', () {
    const body =
        '{"id":"addon.test","name":"Test Addon","logo":"https://x/icon.png"}';
    final parsed = jsonDecode(RustLib.instance.parseStremioManifestJson(body))
        as Map<String, dynamic>;
    expect(parsed['name'], 'Test Addon');
  });

  test('EpisodeMatcher via Rust FFI', () {
    expect(RustLib.isInitialized, isTrue);
    expect(EpisodeMatcher.matches('Show.S03E07.1080p.mkv', 3, 7), isTrue);
    expect(EpisodeMatcher.matches('[RARBG] Show.S03E07.1080p.mkv', 3, 7), isTrue);
    expect(EpisodeMatcher.matches('Show.S03E08.mkv', 3, 7), isFalse);
    expect(EpisodeMatcher.matches('Show.3.07.1080p.mkv', 3, 7), isFalse);
  });

  test('magnet stream E2E (optional)', () async {
    final magnet = torrentE2eMagnet();
    if (magnet == null) return;
    await runMagnetStreamE2e(magnet);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
