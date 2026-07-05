import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/app/rust_delegates.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:api/api/stremio_service.dart';
import 'package:core/utils/episode_matcher.dart';
import 'package:rust/rust.dart';
import 'package:scrapers/scrapers/scraper_parse.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ForjaEngine.init();
    installRustAppDelegates();
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

  test('IPTV Xtream categories delegate wired', () {
    expect(IptvClientBackend.parseCategoriesJson, isNotNull);
    const json = '[{"category_id":"1","category_name":"Sports"}]';
    final rows =
        jsonDecode(IptvClientBackend.parseCategoriesJson!(json)) as List;
    expect(rows.first['name'], 'Sports');
  });

  test('stream provider movie URL', () {
    final url = ForjaEngine.buildMovieUrl('vidlink', '550');
    expect(url, 'https://vidlink.pro/movie/550');
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

  test('Stremio resource URL delegate wired', () {
    expect(StremioServiceBackend.buildResourceUrl, isNotNull);
    final url = StremioServiceBackend.buildResourceUrl!(
      'https://addon.example/api?token=abc',
      '/stream/movie/tt123.json',
    );
    expect(url, 'https://addon.example/api/stream/movie/tt123.json?token=abc');
  });

  test('Stremio manifest JSON delegate wired', () {
    expect(StremioServiceBackend.parseManifestJson, isNotNull);
    const body =
        '{"id":"addon.test","name":"Test Addon","logo":"https://x/icon.png"}';
    final json = StremioServiceBackend.parseManifestJson!(body);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed['name'], 'Test Addon');
  });

  test('Knaben scraper delegate wired', () {
    expect(ScraperParseBackend.parseKnaben, isNotNull);
    const html = '''
<table><tbody><tr>
<td class="text-wrap"><a href="magnet:?xt=urn:btih:abc" title="Show S01E01">Show</a></td>
<td>1.2 GB</td><td></td><td>100</td>
</tr></tbody></table>
''';
    final rows = ScraperParseBackend.parseKnaben!(html);
    expect(rows, hasLength(1));
    expect(rows.first['magnet'], startsWith('magnet:'));
  });

  test('EpisodeMatcher delegate wired', () {
    expect(EpisodeMatcherBackend.matches, isNotNull);
    expect(EpisodeMatcher.matches('Show.S03E07.1080p.mkv', 3, 7), isTrue);
    expect(EpisodeMatcher.matches('[RARBG] Show.S03E07.1080p.mkv', 3, 7), isTrue);
    expect(EpisodeMatcher.matches('Show.S03E08.mkv', 3, 7), isFalse);
    expect(EpisodeMatcher.matches('Show.3.07.1080p.mkv', 3, 7), isFalse);
  });
}
