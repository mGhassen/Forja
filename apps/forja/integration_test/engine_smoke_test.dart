import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/app/rust_delegates.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja_rust/forja_rust.dart';
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
}
