import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/extractors/core/stream_crypto.dart';
import 'package:forja/shared/nuvio/crypto_aes.dart';
import 'package:forja/shared/extractors/providers/kisskh/kisskh_kkey.dart';
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

    test('panel walk skips host sniff plugins', () {
      final pack = EnginePack.fromJson({
        'plugins': [
          {'id': 'videasy', 'entry': 'a.js', 'kind': 'http'},
          {'id': 'vidsrc', 'kind': 'host', 'hostId': 'vidsrc'},
          {'id': 'vidlink', 'entry': 'b.js', 'kind': 'http'},
          {'id': 'vidnest', 'kind': 'host', 'hostId': 'vidnest'},
          {
            'id': 'hop-doodstream',
            'entry': 'hops/doodstream.js',
            'kind': 'hop',
            'hosts': ['dood.li'],
          },
        ],
      }, sourceUrl: 'asset:x');
      expect(orderedEnginePluginIds([pack]), ['videasy', 'vidlink']);
      expect(enabledEnginePluginIds([pack]), {'videasy', 'vidlink'});
      expect(
        hopPluginIdForUrl('https://dood.li/e/abc', pack.plugins),
        'hop-doodstream',
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

    test('batches the next unfetched selected plugins', () {
      expect(
        nextEnginePluginBatch(
          orderedIds: const ['a', 'b', 'c', 'd', 'e'],
          selectedIds: const {'a', 'c', 'd', 'e'},
          fetchedIds: const {'a'},
          limit: 2,
        ),
        ['c', 'd'],
      );
      expect(
        nextEnginePluginBatch(
          orderedIds: const ['a', 'b', 'c'],
          selectedIds: const {'a', 'c'},
          fetchedIds: const {'a', 'c'},
          limit: 10,
        ),
        isEmpty,
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
    test('engine.json lists HTTP chips and hop plugins', () async {
      final jsonStr = await rootBundle.loadString(
        'assets/providers/engine.json',
      );
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plugins = map['plugins'] as List;
      final parsed = [
        for (final p in plugins)
          EnginePlugin.fromJson(Map<String, dynamic>.from(p as Map)),
      ];
      final ids = [for (final p in parsed) p.id];
      expect(
        ids,
        containsAll([
          'videasy',
          'vidlink',
          'vixsrc',
          'dooflix',
          'yflix',
          'vidnest',
          'vidrock',
          'vidfast',
          'vidsrcsbs',
          'cinesrc',
          'vidsrc',
          'webstreamr',
          'kisskh',
          'moviebox',
          '4khdhub',
          'hianime',
          'multiembed',
          'kickassanime',
          'cineby',
          'goated',
          'meowtv',
          'peachify',
          'vidsync',
          'vidup',
          'movieblast',
          'streamflix',
          'animex',
          'anizone',
          'netmirror',
          'castle',
          'xprime',
          'dvdplay',
          'hop-doodstream',
          'hop-voe',
          'hop-mixdrop',
          'hop-abyss',
          'hop-megaup',
          'hop-rapidshare',
        ]),
      );
      expect(parsed.firstWhere((p) => p.id == 'videasy').isHttp, isTrue);
      expect(parsed.firstWhere((p) => p.id == 'hop-doodstream').isHop, isTrue);
      expect(
        parsed.firstWhere((p) => p.id == 'hop-doodstream').isExtractable,
        isFalse,
      );
      expect(parsed.firstWhere((p) => p.id == 'mycima').enabled, isFalse);
      expect(parsed.firstWhere((p) => p.id == 'hop-flixcloud').isHop, isTrue);
      expect(
        parsed.firstWhere((p) => p.id == 'hop-flixcloud').isExtractable,
        isFalse,
      );
      expect(parsed.firstWhere((p) => p.id == 'vidrock').entry, 'vidrock.js');
      expect(parsed.firstWhere((p) => p.id == 'hexa').entry, 'hexa.js');
      expect(parsed.firstWhere((p) => p.id == 'hianime').entry, 'hianime.js');
      expect(
        parsed.firstWhere((p) => p.id == 'kickassanime').entry,
        'kickassanime.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'multiembed').entry,
        'multiembed.js',
      );
      expect(parsed.firstWhere((p) => p.id == 'cineby').entry, 'videasy.js');
      expect(
        parsed.firstWhere((p) => p.id == 'cineby').config['origin'],
        'https://www.cineby.at',
      );
      expect(parsed.firstWhere((p) => p.id == 'goated').entry, 'goated.js');
      expect(
        parsed.firstWhere((p) => p.id == 'goated').config['api'],
        'https://api.reallyfast.xyz',
      );
      expect(parsed.firstWhere((p) => p.id == 'meowtv').entry, 'meowtv.js');
      expect(parsed.firstWhere((p) => p.id == 'peachify').entry, 'peachify.js');
      expect(parsed.firstWhere((p) => p.id == 'vidsync').entry, 'vidsync.js');
      expect(parsed.firstWhere((p) => p.id == 'vidup').entry, 'vidup.js');
      expect(parsed.firstWhere((p) => p.id == 'moviebox').entry, 'moviebox.js');
      expect(
        parsed.firstWhere((p) => p.id == 'moviebox').config['api'],
        'https://h5-api.aoneroom.com',
      );
      expect(parsed.firstWhere((p) => p.id == '4khdhub').entry, '4khdhub.js');
      expect(
        parsed.firstWhere((p) => p.id == 'movieblast').entry,
        'movieblast.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'streamflix').entry,
        'streamflix.js',
      );
      expect(parsed.firstWhere((p) => p.id == 'animex').entry, 'animex.js');
      expect(parsed.firstWhere((p) => p.id == 'anizone').entry, 'anizone.js');
      expect(
        parsed.firstWhere((p) => p.id == 'netmirror').entry,
        'netmirror.js',
      );
      expect(parsed.firstWhere((p) => p.id == 'castle').entry, 'castle.js');
      expect(parsed.firstWhere((p) => p.id == 'xprime').entry, 'xprime.js');
      expect(parsed.firstWhere((p) => p.id == 'dvdplay').entry, 'dvdplay.js');
      expect(
        parsed.firstWhere((p) => p.id == 'xprime').config['backend'],
        'https://backend.xprime.tv',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'dvdplay').config['searchBase'],
        'https://dvdplay.xyz/search.php?q=',
      );
      expect(
        parsed.firstWhere((p) => p.id == '4khdhub').config['domainsUrl'],
        'https://raw.githubusercontent.com/phisher98/TVVVV/refs/heads/main/domains.json',
      );
      expect(parsed.firstWhere((p) => p.id == 'hop-abyss').isHop, isTrue);
      expect(parsed.firstWhere((p) => p.id == 'hop-megaup').isHop, isTrue);
      expect(parsed.firstWhere((p) => p.id == 'cinejoy').entry, 'encdec.js');
      expect(
        parsed.firstWhere((p) => p.id == 'vidrock').config['origin'],
        'https://vidrock.ru',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'vidrock').config['aesKey'],
        isNotEmpty,
      );
      expect(parsed.firstWhere((p) => p.id == 'dooflix').enabled, isTrue);
      expect(
        enabledEnginePluginIds([
          EnginePack(
            sourceUrl: 'asset:x',
            name: 'Forja',
            version: '1',
            plugins: parsed,
          ),
        ]),
        isNot(contains('hop-doodstream')),
      );
    });

    test('dedicated extractors are real ports, not wrapper scrapes', () async {
      final vidrock = await rootBundle.loadString(
        'assets/providers/vidrock.js',
      );
      expect(vidrock.contains('aesdec.nuvioapp.space'), isFalse);
      expect(vidrock.contains('AES.encrypt'), isFalse);
      expect(vidrock.contains('AES.decrypt'), isTrue);
      expect(vidrock.contains('mode.GCM'), isTrue);
      expect(vidrock.contains('/api/'), isTrue);
      expect(vidrock.contains('tv/'), isTrue);

      final hexa = await rootBundle.loadString('assets/providers/hexa.js');
      expect(hexa.contains('enc-hexa'), isTrue);
      expect(hexa.contains('X-Api-Key'), isTrue);
      expect(hexa.contains('X-Cap-Token'), isTrue);

      final vidcore = await rootBundle.loadString(
        'assets/providers/vidcore.js',
      );
      expect(vidcore.contains('enc-vidcore'), isTrue);
      expect(vidcore.contains('dec-vidcore'), isTrue);

      final moviesapi = await rootBundle.loadString(
        'assets/providers/moviesapi.js',
      );
      expect(moviesapi.contains('/api/vidora/v1/'), isTrue);

      final hianime = await rootBundle.loadString(
        'assets/providers/hianime.js',
      );
      expect(hianime.contains('megaplay'), isTrue);
      expect(hianime.contains('getSources'), isTrue);

      final kaa = await rootBundle.loadString(
        'assets/providers/kickassanime.js',
      );
      expect(kaa.contains('/api/fsearch'), isTrue);
      expect(kaa.contains('krussdomi.com'), isTrue);

      final cinebyCfg =
          ((jsonDecode(
                        await rootBundle.loadString(
                          'assets/providers/engine.json',
                        ),
                      )
                      as Map)['plugins']
                  as List)
              .cast<Map>()
              .firstWhere((p) => p['id'] == 'cineby');
      expect(cinebyCfg['entry'], 'videasy.js');
      expect(cinebyCfg['config']['origin'], 'https://www.cineby.at');

      final goated = await rootBundle.loadString('assets/providers/goated.js');
      expect(goated.contains('aesdec.nuvioapp.space'), isFalse);
      expect(goated.contains('/api/resolve'), isTrue);
      expect(goated.contains('/api/challenge'), isTrue);
      expect(goated.contains('solvePow'), isTrue);

      final meowtv = await rootBundle.loadString('assets/providers/meowtv.js');
      expect(meowtv.contains('/streams/'), isTrue);
      expect(meowtv.contains('dec-meowtv'), isTrue);

      final peachify = await rootBundle.loadString(
        'assets/providers/peachify.js',
      );
      expect(peachify.contains('dec-peachify'), isTrue);

      final vidsync = await rootBundle.loadString(
        'assets/providers/vidsync.js',
      );
      expect(vidsync.contains('enc-vidsync'), isTrue);
      expect(vidsync.contains('dec-vidsync'), isTrue);

      final vidup = await rootBundle.loadString('assets/providers/vidup.js');
      expect(vidup.contains('enc-vidup'), isTrue);
      expect(vidup.contains('dec-vidup'), isTrue);

      final moviebox = await rootBundle.loadString(
        'assets/providers/moviebox.js',
      );
      expect(moviebox.contains('wefeed-h5api-bff/subject/search'), isTrue);
      expect(moviebox.contains('wefeed-h5api-bff/subject/download'), isTrue);

      final fourkhdhub = await rootBundle.loadString(
        'assets/providers/4khdhub.js',
      );
      expect(fourkhdhub.contains('HubCloud 10Gbps'), isTrue);
      expect(fourkhdhub.contains("j['4khdhub']"), isTrue);
      expect(fourkhdhub.contains('.movie-card'), isTrue);

      final movieblast = await rootBundle.loadString(
        'assets/providers/movieblast.js',
      );
      expect(movieblast.contains('HmacSHA256'), isTrue);
      expect(movieblast.contains('/api/search/'), isTrue);

      final streamflix = await rootBundle.loadString(
        'assets/providers/streamflix.js',
      );
      expect(streamflix.contains('/data.json'), isTrue);
      expect(streamflix.contains('config-streamflixapp.json'), isTrue);

      final animex = await rootBundle.loadString('assets/providers/animex.js');
      expect(animex.contains('cfg.gql'), isTrue);
      expect(animex.contains('searchAnime'), isTrue);
      expect(animex.contains('/sources'), isTrue);

      final anizone = await rootBundle.loadString(
        'assets/providers/anizone.js',
      );
      expect(anizone.contains('id-mapping-api-malid'), isTrue);
      expect(anizone.contains("media-player"), isTrue);

      final netmirror = await rootBundle.loadString(
        'assets/providers/netmirror.js',
      );
      expect(netmirror.contains('checknewtv.php'), isTrue);
      expect(netmirror.contains('/newtv/player.php'), isTrue);

      final castle = await rootBundle.loadString('assets/providers/castle.js');
      expect(castle.contains('getSecurityKey'), isTrue);
      expect(castle.contains('film-api/v2.0.1/movie/getVideo2'), isTrue);

      final xprime = await rootBundle.loadString('assets/providers/xprime.js');
      expect(xprime.contains('enc-xprime'), isTrue);
      expect(xprime.contains('dec-xprime'), isTrue);
      expect(xprime.contains('backend.xprime.tv'), isTrue);
      expect(xprime.contains("/rage?id="), isTrue);

      final dvdplay = await rootBundle.loadString(
        'assets/providers/dvdplay.js',
      );
      expect(dvdplay.contains('/search.php?q='), isTrue);
      expect(dvdplay.contains('resolveHubCloud'), isTrue);
      expect(dvdplay.contains('pixeldrain.net/api/file'), isTrue);
    });

    test('EnginePlugin host kind resolves hostProviderId', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'vidsrc',
        'name': 'VSEmbed',
        'kind': 'host',
      });
      expect(plugin.isHost, isTrue);
      expect(plugin.isExtractable, isFalse);
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
      final mirrors =
          ((jsonDecode(jsonStr) as Map)['plugins'] as List)
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

    test('vidnest.js uses the Forja custom-alphabet cipher', () async {
      final src = await rootBundle.loadString('assets/providers/vidnest.js');
      expect(
        src,
        contains(
          'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=',
        ),
      );
      expect(src, contains('decryptCipher'));
      expect(src, contains('ctx.host(\'vidnest\')'));
    });

    test('hop scripts export extract(ctx) and use ctx.url', () async {
      for (final name in [
        'doodstream',
        'voe',
        'filemoon',
        'streamtape',
        'vidmoly',
        'mixdrop',
      ]) {
        final src = await rootBundle.loadString(
          'assets/providers/hops/$name.js',
        );
        expect(src, contains('function extract(ctx)'));
        expect(src, contains('ctx.url'));
      }
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

    test('extract(ctx) can disable ctx.host fallback', () async {
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'host-disabled-test',
        code: '''
function extract(ctx) {
  return ctx.host('vidfast').then(function(rows) {
    return [{
      url: 'https://cdn.example/nohost.m3u8',
      title: String(rows.length)
    }];
  });
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'host-disabled-test',
        tmdbId: '1',
        type: 'movie',
        allowHostFallback: false,
      );
      expect(streams.single['title'], '0');
    });

    test('extract(ctx) AES-GCM decrypts vidrock-style iv||ct', () async {
      const keyHex =
          '7f3e9c2a8b5d1f4e6a9c3b7d2e5f8a1c4b6d9e2f5a8c1b4d7e9f2a5c8b1d4e7f';
      const ivHex = '0102030405060708090a0b0c';
      const plain = 'https://cdn.example/master.m3u8';
      final ctHex = aesHex(
        mode: 'AES-GCM',
        keyHex: keyHex,
        ivHex: ivHex,
        dataHex: hexFromBytes(utf8.encode(plain)),
        encrypt: true,
      );
      final enc = base64UrlEncode(
        bytesFromHex(ivHex + ctHex),
      ).replaceAll('=', '');
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'gcm-test',
        code:
            '''
function extract(ctx) {
  var key = CryptoJS.enc.Hex.parse(${jsonEncode(keyHex)});
  var packed = CryptoJS.enc.Base64.parse(${jsonEncode(enc)});
  var hex = CryptoJS.enc.Hex.stringify(packed);
  var iv = CryptoJS.enc.Hex.parse(hex.substring(0, 24));
  var ct = CryptoJS.enc.Hex.parse(hex.substring(24));
  var pt = CryptoJS.AES.decrypt({ ciphertext: ct }, key, {
    iv: iv, mode: CryptoJS.mode.GCM
  });
  return [{ url: CryptoJS.enc.Utf8.stringify(pt), name: 'ok' }];
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'gcm-test',
        tmdbId: '1',
        type: 'movie',
      );
      expect(streams.single['url'], plain);
    });

    test('ctx.hop dispatches to a hop plugin by hostname', () async {
      final rt = EngineRuntime.instance;
      rt.registerHops([
        EnginePlugin(
          id: 'hop-test',
          name: 'HopTest',
          entry: 'x.js',
          kind: 'hop',
          hosts: const ['hop.test'],
        ),
      ]);
      await rt.loadPlugin(
        pluginId: 'hop-test',
        code: '''
function extract(ctx) {
  return Promise.resolve([{ url: ctx.url + '/direct.mp4', name: 'hopped' }]);
}
''',
      );
      await rt.loadPlugin(
        pluginId: 'http-hop',
        code: '''
function extract(ctx) {
  return ctx.hop('https://hop.test/e/abc');
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'http-hop',
        tmdbId: '1',
        type: 'movie',
      );
      expect(streams.single['url'], 'https://hop.test/e/abc/direct.mp4');
    });
  });

  group('KissKhKkey', () {
    test('matches rust golden episode 171699 video', () {
      expect(
        KissKhKkey.generate(171699),
        '56697480CCBF13FF11E371C19696FBA7601E1C569630FF4001DBEBAB511F65357C5D712E4AD39F6E859770F5A0763B06E95ECB5142C0FE2DF561F722DB89E5F38D05E72CAA2FB6700380C17689688661D2D0631EDF1D579DF3127B9D313427CBD092C9B4D546EB6F69E2CA9760E02535750C1496D08C7C8937ACC42EE4B5334A',
      );
    });

    test('matches rust golden episode 1 video', () {
      expect(
        KissKhKkey.generate(1),
        '23DC3EEF3D9B5DF88849AF476B008D4A58F9F3ACAB38A549C34AB3E473B7B3328BF080D795B810DF74E2DD76B6998B74CFA8BA86F6D6475708E88A44B762E3C576A1990EFFE4FF40291730B851812E47A89F38E89D57750449910D068F584D8C62EF5E91C838C93469EC3C4CF54D6C12A694E331B7A27040C722FA017BB6FCEC',
      );
    });
  });
}
