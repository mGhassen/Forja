import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:streaming/streaming.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ForjaEngine.init();
  });

  setUp(() {
    if (ForjaRust.isInitialized) {
      ForjaRust.instance.torrentEngineStop();
      ForjaRust.instance.torrentStop();
    }
  });

  tearDown(() {
    if (ForjaRust.isInitialized) {
      ForjaRust.instance.torrentEngineStop();
      ForjaRust.instance.torrentStop();
    }
  });

  test('ForjaEngine loads native library', () {
    expect(
      ForjaEngine.isReady,
      isTrue,
      reason: 'Run ./scripts/build_rust.sh before integration tests',
    );
    expect(ForjaRust.instance.version, isNotEmpty);
  });

  testWidgets('flutter binding boots', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });

  test('M3U parse returns channels', () {
    const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="ch1" tvg-name="News" tvg-logo="http://logo.example/icon.png" group-title="News",News HD
http://stream.example/live
''';
    final channels = ForjaEngine.parseM3uChannels(content);
    expect(channels, hasLength(1));
    expect(channels.first['name'], 'News HD');
    expect(channels.first['group'], 'News');
  });

  test('IPTV Xtream categories via Rust FFI', () {
    expect(ForjaRust.isInitialized, isTrue);
    const json = '[{"category_id":"1","category_name":"Sports"}]';
    final rows =
        jsonDecode(ForjaRust.instance.parseXtreamCategoriesJson(json)) as List;
    expect(rows.first['name'], 'Sports');
  });

  test('stream provider movie URL', () {
    final url = ForjaEngine.requireMovieUrl('vidlink', '550');
    expect(url, 'https://vidlink.pro/movie/550');
  });

  test('torrent peer limit + engine restart', () async {
    final svc = TorrentStreamService();
    expect(await svc.start(), isTrue);
    await svc.applyConnectionsLimit(75);
    expect(svc.state, EngineState.ready);
  });

  test('torrent engine starts on loopback', () {
    final port = ForjaRust.instance.torrentEngineStart(0);
    expect(port, greaterThan(0));
    expect(ForjaRust.instance.torrentEnginePort(), port);
  });

  test('invalid magnet rejected', () {
    ForjaRust.instance.torrentEngineStart(0);
    expect(ForjaRust.instance.torrentStart('not-a-magnet'), isFalse);
  });

  test('Stremio resource URL via Rust FFI', () {
    expect(ForjaRust.isInitialized, isTrue);
    final url = ForjaRust.instance.buildStremioResourceUrl(
      'https://addon.example/api?token=abc',
      '/stream/movie/tt123.json',
    );
    expect(url, 'https://addon.example/api/stream/movie/tt123.json?token=abc');
  });

  test('Stremio manifest JSON via Rust FFI', () {
    const body =
        '{"id":"addon.test","name":"Test Addon","logo":"https://x/icon.png"}';
    final parsed = jsonDecode(ForjaRust.instance.parseStremioManifestJson(body))
        as Map<String, dynamic>;
    expect(parsed['name'], 'Test Addon');
  });

  test('Knaben HTML parse via Rust FFI', () {
    expect(ForjaRust.isInitialized, isTrue);
    const html = '''
<table><tbody><tr>
<td class="text-wrap"><a href="magnet:?xt=urn:btih:abc" title="Show S01E01">Show</a></td>
<td>1.2 GB</td><td></td><td>100</td>
</tr></tbody></table>
''';
    final rows = jsonDecode(ForjaRust.instance.parseKnabenHtmlJson(html)) as List;
    expect(rows, hasLength(1));
    expect(rows.first['magnet'], startsWith('magnet:'));
  });

  test('EpisodeMatcher via Rust FFI', () {
    expect(ForjaRust.isInitialized, isTrue);
    expect(EpisodeMatcher.matches('Show.S03E07.1080p.mkv', 3, 7), isTrue);
    expect(EpisodeMatcher.matches('[RARBG] Show.S03E07.1080p.mkv', 3, 7), isTrue);
    expect(EpisodeMatcher.matches('Show.S03E08.mkv', 3, 7), isFalse);
    expect(EpisodeMatcher.matches('Show.3.07.1080p.mkv', 3, 7), isFalse);
  });

  test('magnet stream E2E (optional)', () async {
    final run = Platform.environment['FORJA_TORRENT_E2E'] == '1';
    final magnet = Platform.environment['FORJA_TORRENT_MAGNET'];
    if (!run || magnet == null || magnet.isEmpty) {
      return;
    }
    ForjaRust.instance.torrentSetPeerLimit(50);
    expect(ForjaRust.instance.torrentEngineStart(0), greaterThan(0));

    final listJson = ForjaRust.instance.torrentListFilesJson(magnet);
    final listParsed = jsonDecode(listJson) as Map<String, dynamic>;
    expect(listParsed['error'], isNull, reason: '${listParsed['error']}');
    final files = listParsed['files'] as List?;
    expect(files, isNotEmpty);

    final json = ForjaRust.instance.torrentStreamJson(magnet);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed['error'], isNull, reason: '${parsed['error']}');
    final url = parsed['url'] as String?;
    expect(url, isNotEmpty);
    expect(url, startsWith('http://127.0.0.1:'));

    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url!));
    req.headers.set('Range', 'bytes=0-1023');
    final resp = await req.close();
    expect(resp.statusCode, anyOf(200, 206));
    final bytes = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(bytes.length, greaterThan(0));
    client.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
