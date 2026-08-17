import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine_js/engine_js.dart';
import 'package:forja/shared/extractors/core/stream_crypto.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:rust/rust.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnginePack.parse', () {
    test('reads a multi-plugin pack', () {
      final pack = EnginePack.fromJson({
        'schema': 1,
        'name': 'Forja',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'videasy',
            'name': 'Videasy',
            'entry': 'videasy.js',
            'types': ['movie', 'tv'],
            'kind': 'http',
          },
        ],
      }, sourceUrl: 'asset:providers/engine.json');
      expect(pack.plugins, hasLength(1));
      expect(pack.plugins.first.id, 'videasy');
      expect(pack.plugins.first.isHttp, isTrue);
      expect(enabledEnginePluginIds([pack]), {'videasy'});
    });

    test('treats a root plugin as a one-plugin pack', () {
      final pack = EnginePack.fromJson({
        'id': 'videasy',
        'name': 'Videasy',
        'version': '1.0.0',
        'entry': 'extract.js',
        'types': ['movie', 'tv'],
        'kind': 'http',
      }, sourceUrl: 'https://example.com/engine.json');
      expect(pack.plugins.single.id, 'videasy');
      expect(pack.name, 'Videasy');
    });

    test('skips sniff plugins from enabled ids', () {
      final pack = EnginePack.fromJson({
        'plugins': [
          {'id': 'http-one', 'entry': 'a.js', 'kind': 'http'},
          {'id': 'sniff-one', 'entry': 'b.js', 'kind': 'sniff'},
        ],
      }, sourceUrl: 'asset:x');
      expect(enabledEnginePluginIds([pack]), {'http-one'});
    });
  });

  group('engineJS chips', () {
    test('kind is engine, All chip is all_engine, plugin chips use engine:', () {
      expect(EngineJsIds.kind, 'engine');
      expect(EngineJsIds.kind, isNot('forja'));
      expect(EngineJsIds.allChip, 'all_engine');
      expect(EngineJsIds.pluginChip('videasy'), 'engine:videasy');
      expect(EngineJsIds.pluginIdFromChip('engine:videasy'), 'videasy');
      expect(EngineJsIds.isAllChip('all_engine'), isTrue);
      expect(EngineJsIds.isAllChip('forja'), isFalse);
    });

    test('All tap selects every enabled plugin, then clears', () {
      expect(
        nextEngineSelectedAfterAllTap(
          selectedIds: const {'videasy'},
          enabledIds: const {'videasy', 'other'},
        ),
        {'videasy', 'other'},
      );
      expect(
        nextEngineSelectedAfterAllTap(
          selectedIds: const {'videasy', 'other'},
          enabledIds: const {'videasy', 'other'},
        ),
        isEmpty,
      );
    });

    test('walks the next unfetched selected plugin', () {
      expect(
        nextEnginePluginId(
          orderedIds: const ['a', 'b', 'c'],
          selectedIds: const {'a', 'c'},
          fetchedIds: const {'a'},
        ),
        'c',
      );
      expect(
        nextEnginePluginId(
          orderedIds: const ['a', 'b', 'c'],
          selectedIds: const {'a', 'c'},
          fetchedIds: const {'a', 'c'},
        ),
        isNull,
      );
    });
  });

  group('Forja tab magnet filter', () {
    test('drops magnets and .torrent URLs', () {
      expect(isTorrentStreamUrl('magnet:?xt=urn:btih:abc'), isTrue);
      expect(isTorrentStreamUrl('https://cdn.example/file.torrent'), isTrue);
      expect(isTorrentStreamUrl('https://cdn.example/a.m3u8'), isFalse);
    });
  });

  group('Torrents All alias', () {
    test('legacy forja chip id still means All', () {
      expect(TorrentSearchProviders.isAllChip('forja'), isTrue);
      expect(TorrentSearchProviders.isAllChip(TorrentSearchProviders.allId), isTrue);
      expect(TorrentSearchProviders.isAllChip('all_engine'), isFalse);
    });
  });

  group('catalog vs webstreaming ids', () {
    test('engine:videasy is Sources, not green Play', () {
      expect(isCatalogSourcesMode('engine:videasy'), isTrue);
      expect(isWebStreamProviderId('engine:videasy'), isFalse);
      expect(isWebStreamProviderId('videasy'), isTrue);
    });

    test('catalogHttpPlayProviderId uses engine chip for Forja rows', () {
      expect(
        catalogHttpPlayProviderId({'_enginePluginId': 'videasy'}),
        'engine:videasy',
      );
      expect(catalogHttpPlayProviderId({'url': 'https://x'}), 'stremio_direct');
    });
  });

  group('TorrentSourceKindFilter', () {
    testWidgets('shows Forja first when showEngine is on', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TorrentSourceKindFilter(
              selected: 'engine',
              showTorrents: true,
              showStremio: true,
              showNuvio: true,
              showEngine: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final labels = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList();
      expect(labels.indexOf('Forja'), lessThan(labels.indexOf('Torrents')));
      expect(labels.indexOf('Torrents'), lessThan(labels.indexOf('Stremio')));
      expect(labels.indexOf('Stremio'), lessThan(labels.indexOf('Nuvio')));
    });

    testWidgets('shows Forja when showEngine is on', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TorrentSourceKindFilter(
              selected: 'engine',
              showTorrents: true,
              showStremio: true,
              showNuvio: true,
              showEngine: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Forja'), findsOneWidget);
      expect(find.text('Torrents'), findsOneWidget);
      expect(find.text('Stremio'), findsOneWidget);
      expect(find.text('Nuvio'), findsOneWidget);
    });

    testWidgets('lists Forja before Torrents', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TorrentSourceKindFilter(
              selected: 'engine',
              showTorrents: true,
              showStremio: true,
              showNuvio: true,
              showEngine: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .whereType<String>()
          .where((s) => const {'Forja', 'Torrents', 'Stremio', 'Nuvio'}.contains(s))
          .toList();
      expect(labels.indexOf('Forja'), lessThan(labels.indexOf('Torrents')));
    });

    testWidgets('hides Forja when showEngine is off', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TorrentSourceKindFilter(
              selected: 'torrents',
              showTorrents: true,
              showStremio: true,
              showNuvio: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Forja'), findsNothing);
    });
  });

  group('bundled Forja pack', () {
    test('engine.json lists HTTP movie/tv plugins', () async {
      final jsonStr = await rootBundle.loadString('assets/providers/engine.json');
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plugins = map['plugins'] as List;
      final ids = [for (final p in plugins) (p as Map)['id'] as String];
      expect(ids, containsAll(['videasy', 'vidlink', 'vixsrc', 'dooflix', 'yflix']));
      for (final p in plugins) {
        expect((p as Map)['kind'], 'http');
      }
    });

    test('fans out every player.videasy.to Servers-tab mirror', () async {
      final src = await rootBundle.loadString('assets/providers/videasy.js');
      expect(src, contains("endpoint: 'cdn'"));
      expect(src, contains("endpoint: 'downloader2'"));
      expect(src, contains("endpoint: 'm4uhd'"));
      expect(src, contains("endpoint: 'vsrc'"));
      expect(src, contains("endpoint: 'hdmovie'"));
      expect(src, contains("endpoint: 'meine'"));
      expect(src, contains("endpoint: 'lamovie'"));
      expect(src, contains("endpoint: 'superflix'"));
      expect(src, contains("name: 'Yoru'"));
      expect(src, contains("name: 'Raze'"));
      expect(src, contains('Promise.all'));
      expect(src, isNot(contains("/cdn/sources-with-title?' + q")));
    });

    test('vidlink marks MovieBox requiresProxy and strips Referer in JS', () async {
      final src = await rootBundle.loadString('assets/providers/vidlink.js');
      expect(src, contains('requiresProxy'));
      expect(src, contains('hakunaymatata.com'));
    });
    test('vixsrc uses JSON API + embed page (not SSR shell scrape)', () async {
      final src = await rootBundle.loadString('assets/providers/vixsrc.js');
      expect(src, contains('/api/tv/'));
      expect(src, contains('/api/movie/'));
      expect(src, contains('data.src'));
      expect(src, isNot(contains("BASE + '/tv/'")));
    });
  });

  group('catalog Vidlink proxy', () {
    test('catalogStreamRequiresSeekProxy for MovieBox engine rows', () {
      const url =
          'https://bcdn.hakunaymatata.com/resource/h265/x.mp4?sign=a&t=1';
      expect(
        catalogStreamRequiresSeekProxy({
          'url': url,
          '_enginePluginId': 'vidlink',
          'requires_proxy': true,
        }),
        isTrue,
      );
      expect(
        catalogStreamRequiresSeekProxy({
          'url': url,
          '_enginePluginId': 'videasy',
        }),
        isFalse,
      );
    });
  });

  group('EngineJsRuntime host', () {
    test('extract(ctx) decrypts via ctx.streamcrypto', () async {
      const seed = 'test-seed';
      const mediaId = '550';
      const json = '{"ok":true}';
      final payload = StreamCrypto.encryptForTest(json, seed, mediaId);
      final rt = EngineJsRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'crypto-test',
        code: '''
function extract(ctx) {
  var body = ctx.streamcrypto.decrypt(${jsonEncode(payload)}, ${jsonEncode(seed)}, ctx.tmdbId);
  return Promise.resolve([{ url: 'https://cdn.example/a.m3u8', title: body }]);
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'crypto-test',
        tmdbId: mediaId,
        type: 'movie',
      );
      expect(streams, hasLength(1));
      expect(streams.single['url'], 'https://cdn.example/a.m3u8');
      expect(streams.single['title'], json);
    });
  });
}
