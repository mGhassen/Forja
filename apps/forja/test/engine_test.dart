import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/engine.dart';
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

  group('engine chips', () {
    test(
      'kind is engine, All chip is all_engine, plugin chips use engine:',
      () {
        expect(EngineIds.kind, 'engine');
        expect(EngineIds.kind, isNot('forja'));
        expect(EngineIds.allChip, 'all_engine');
        expect(EngineIds.pluginChip('videasy'), 'engine:videasy');
        expect(EngineIds.pluginIdFromChip('engine:videasy'), 'videasy');
        expect(EngineIds.isAllChip('all_engine'), isTrue);
        expect(EngineIds.isAllChip('forja'), isFalse);
      },
    );

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

    test('orders HTTP plugins before host sniff plugins', () {
      final pack = EnginePack.fromJson({
        'plugins': [
          {'id': 'videasy', 'entry': 'a.js', 'kind': 'http'},
          {'id': 'vidsrc', 'kind': 'host', 'hostId': 'vidsrc'},
          {'id': 'vidlink', 'entry': 'b.js', 'kind': 'http'},
          {'id': 'vidnest', 'kind': 'host', 'hostId': 'vidnest'},
        ],
      }, sourceUrl: 'asset:x');
      expect(orderedEnginePluginIds([pack]), [
        'videasy',
        'vidlink',
        'vidsrc',
        'vidnest',
      ]);
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
      expect(
        TorrentSearchProviders.isAllChip(TorrentSearchProviders.allId),
        isTrue,
      );
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

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .toList();
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
          .where(
            (s) => const {'Forja', 'Torrents', 'Stremio', 'Nuvio'}.contains(s),
          )
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
    test('engine.json lists HTTP + host sniff plugins', () async {
      final jsonStr = await rootBundle.loadString(
        'assets/providers/engine.json',
      );
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plugins = map['plugins'] as List;
      final ids = [for (final p in plugins) (p as Map)['id'] as String];
      expect(
        ids,
        containsAll([
          'videasy',
          'vidlink',
          'vixsrc',
          'vidsrc',
          'vidsrcwin',
          'vidnest',
          'vidrock',
          'vidsrcsbs',
          'service111477',
          'webstreamr',
        ]),
      );
      final kinds = {
        for (final p in plugins)
          (p as Map)['id'] as String: p['kind'] as String,
      };
      expect(kinds['videasy'], 'http');
      expect(kinds['vidsrc'], 'host');
      expect(kinds['webstreamr'], 'host');
      expect(kinds['dooflix'], 'http');
      expect(
        (plugins.firstWhere((p) => (p as Map)['id'] == 'dooflix')
            as Map)['enabled'],
        isFalse,
      );
    });

    test('EnginePlugin host kind resolves hostProviderId', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'vidsrc',
        'name': 'VSEmbed',
        'kind': 'host',
      });
      expect(plugin.isHost, isTrue);
      expect(plugin.isExtractable, isTrue);
      expect(plugin.hostProviderId, 'vidsrc');
    });

    test('fans out every player.videasy.to Servers-tab mirror', () async {
      final src = await rootBundle.loadString('assets/providers/videasy.js');
      expect(src, contains('ctx.config'));
      expect(src, contains('cfg.mirrors'));
      expect(src, contains('mirror.endpoint'));
      expect(src, contains('mirror.name'));
      expect(src, contains('Promise.all'));
      expect(src, contains('parseM3u8'));
      expect(src, contains('quality:'));
      expect(src, contains('language:'));
      expect(src, contains('ctx.crypto.streamDecrypt'));
      final jsonStr = await rootBundle.loadString(
        'assets/providers/engine.json',
      );
      final mirrors = ((jsonDecode(jsonStr) as Map)['plugins'] as List)
          .cast<Map>()
          .firstWhere((p) => p['id'] == 'videasy')['config']['mirrors']
          as List;
      expect(mirrors.map((m) => m['endpoint']), contains('cdn'));
      expect(mirrors.map((m) => m['name']), contains('Yoru'));
      expect(mirrors.map((m) => m['name']), contains('Raze'));
    });

    test('engine.json HTTP plugins ship opaque config bags', () async {
      final jsonStr = await rootBundle.loadString(
        'assets/providers/engine.json',
      );
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plugins = map['plugins'] as List;
      Map<String, dynamic> plugin(String id) => Map<String, dynamic>.from(
            plugins.firstWhere((p) => (p as Map)['id'] == id) as Map,
          );
      expect(plugin('videasy')['config'], isNotNull);
      expect(plugin('videasy')['config']['mirrors'], isA<List>());
      expect(plugin('vidlink')['config']['api'], isNotEmpty);
      expect(plugin('vixsrc')['config']['base'], isNotEmpty);
      expect(plugin('vixsrc')['config']['subs'], isNotEmpty);
    });

    test('EnginePlugin.config parses and persists', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'videasy',
        'name': 'Videasy',
        'entry': 'videasy.js',
        'config': {
          'api': 'https://api.example',
          'mirrors': [
            {'endpoint': 'cdn', 'name': 'Yoru'},
          ],
        },
      });
      expect(plugin.config['api'], 'https://api.example');
      expect(plugin.config['mirrors'], isA<List>());
      expect(plugin.toJson()['config'], isNotNull);
    });

    test('mergeEngineConfig deep-merges maps and replaces lists', () {
      final merged = mergeEngineConfig(
        {
          'api': 'https://base.example',
          'origin': 'https://player.example',
          'mirrors': [
            {'endpoint': 'cdn', 'name': 'A'},
          ],
          'nested': {'a': 1, 'b': 2},
        },
        {
          'api': 'https://overlay.example',
          'mirrors': [
            {'endpoint': 'vsrc', 'name': 'B'},
          ],
          'nested': {'b': 9, 'c': 3},
        },
      );
      expect(merged['api'], 'https://overlay.example');
      expect(merged['origin'], 'https://player.example');
      expect(merged['mirrors'], [
        {'endpoint': 'vsrc', 'name': 'B'},
      ]);
      expect(merged['nested'], {'a': 1, 'b': 9, 'c': 3});
    });

    test(
      'vidlink requests dash-hevc and keeps MovieBox playlist cookies',
      () async {
        final src = await rootBundle.loadString('assets/providers/vidlink.js');
        expect(src, contains('ctx.config'));
        expect(src, contains('X-Playback-Environment'));
        expect(src, contains('dash-hevc'));
        expect(src, contains('playlistHeaders'));
        expect(src, contains('deliveryType === \'dash\''));
        expect(src, contains('hakunaymatata.com'));
        expect(src, contains("name: 'Vidlink'"));
      },
    );
    test(
      'vixsrc uses API, embed parse, m3u8 variants, and wyzie subs',
      () async {
        final src = await rootBundle.loadString('assets/providers/vixsrc.js');
        expect(src, contains('ctx.config'));
        expect(src, contains('/api/tv/'));
        expect(src, contains('/api/movie/'));
        expect(src, contains('parseM3u8Variants'));
        expect(src, contains('ctx.config.subs'));
        expect(src, contains('resolveLegacyPage'));
        expect(src, contains('1080p'));
        expect(src, contains("name: 'Vixsrc'"));
        expect(src, contains('CODECS='));
      },
    );
  });

  group('catalog Vidlink proxy', () {
    test(
      'catalogStreamRequiresSeekProxy only for explicit flag and 111477',
      () {
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
            '_enginePluginId': 'vidlink',
          }),
          isFalse,
        );
        expect(
          catalogStreamRequiresSeekProxy({
            'url': 'https://111477.example/file.mp4',
            '_enginePluginId': 'service111477',
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
      },
    );

    test('catalogStreamExternalSubtitles maps engine rows', () {
      expect(
        catalogStreamExternalSubtitles({
          'subtitles': [
            {
              'url': 'https://sub.example/en.vtt',
              'language': 'en',
              'name': 'English',
            },
          ],
        }),
        [
          {
            'url': 'https://sub.example/en.vtt',
            'language': 'en',
            'name': 'English',
          },
        ],
      );
    });
  });

  group('mapEngineStream', () {
    final plugin = EnginePlugin.fromJson({
      'id': 'videasy',
      'name': 'Videasy',
      'entry': 'videasy.js',
      'kind': 'http',
    });

    test(
      'card title is media SxE year; quality/language/audio go to description',
      () {
        final mapped = mapEngineStream(
          raw: {
            'url': 'https://cdn.example/a.m3u8',
            'name': 'Yoru',
            'quality': '720p',
            'language': 'English',
            'audio': 'AAC',
            'headers': {'Referer': 'https://player.videasy.to/'},
          },
          plugin: plugin,
          mediaTitle: 'Sterling Point',
          year: '2026',
          type: 'tv',
          season: 1,
          episode: 1,
        )!;
        expect(mapped['title'], 'Sterling Point S1E1 - (2026)');
        expect(mapped['description'], '720p AAC English');
        expect(mapped['quality'], '720p');
        expect(mapped['language'], 'English');
        expect(mapped['_addonName'], 'Videasy · Yoru');
        expect(mapped['_enginePluginId'], 'videasy');
        expect(
          (mapped['headers'] as Map)['Referer'],
          'https://player.videasy.to/',
        );
      },
    );

    test('drops auto/English as quality and maps English to language', () {
      final mapped = mapEngineStream(
        raw: {
          'url': 'https://cdn.example/a.m3u8',
          'name': 'Vyse',
          'quality': 'English',
        },
        plugin: plugin,
        mediaTitle: 'Show',
        type: 'movie',
        year: '2024',
      )!;
      expect(mapped['title'], 'Show - (2024)');
      expect(mapped['quality'], isNull);
      expect(mapped['language'], 'English');
      expect(mapped['description'], 'English');
    });

    test('reads 1080p from a Vidlink-style title when quality is missing', () {
      final mapped = mapEngineStream(
        raw: {'url': 'https://cdn.example/a.m3u8', 'title': 'Vidlink · 1080p'},
        plugin: plugin,
        mediaTitle: 'Movie',
        type: 'movie',
        year: '2020',
      )!;
      expect(mapped['quality'], '1080p');
      expect(mapped['description'], '1080p');
      expect(mapped['_addonName'], 'Videasy · Vidlink');
    });
  });

  group('EngineRuntime host', () {
    test('extract(ctx) decrypts via ctx.streamcrypto', () async {
      const seed = 'test-seed';
      const mediaId = '550';
      const json = '{"ok":true}';
      final payload = StreamCrypto.encryptForTest(json, seed, mediaId);
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'crypto-test',
        code:
            '''
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

    test('extract(ctx) decrypts via ctx.crypto.streamDecrypt alias', () async {
      const seed = 'alias-seed';
      const mediaId = '42';
      const json = '{"alias":true}';
      final payload = StreamCrypto.encryptForTest(json, seed, mediaId);
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'crypto-alias',
        code:
            '''
function extract(ctx) {
  var body = ctx.crypto.streamDecrypt(${jsonEncode(payload)}, ${jsonEncode(seed)}, ctx.tmdbId);
  return Promise.resolve([{ url: 'https://cdn.example/b.m3u8', title: body }]);
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'crypto-alias',
        tmdbId: mediaId,
        type: 'movie',
      );
      expect(streams.single['title'], json);
    });

    test('extract(ctx) receives imdbId and config', () async {
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'ctx-meta',
        code: '''
function extract(ctx) {
  return Promise.resolve([{
    url: 'https://cdn.example/meta.m3u8',
    title: ctx.imdbId + '|' + (ctx.config.api || '')
  }]);
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'ctx-meta',
        tmdbId: '99',
        imdbId: 'tt123',
        type: 'movie',
        config: const {'api': 'https://cfg.example'},
      );
      expect(streams.single['title'], 'tt123|https://cfg.example');
    });

    test('extract(ctx) html loads cheerio', () async {
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'html-test',
        code: r'''
function extract(ctx) {
  var $ = ctx.html('<div class="x">hi</div>');
  if (!$) return [];
  var t = $('.x').text();
  return [{ url: 'https://cdn.example/c.m3u8', title: t }];
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'html-test',
        tmdbId: '1',
        type: 'movie',
      );
      expect(streams.single['title'], 'hi');
    });

    test('extract(ctx) crypto MD5 via CryptoJS', () async {
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'md5-test',
        code: '''
function extract(ctx) {
  var h = CryptoJS.MD5('abc').toString();
  return [{ url: 'https://cdn.example/d.m3u8', title: h }];
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'md5-test',
        tmdbId: '1',
        type: 'movie',
      );
      expect(streams.single['title'], '900150983cd24fb0d6963f7d28e17f72');
    });
  });
}
