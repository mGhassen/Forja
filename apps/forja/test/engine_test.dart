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
      }, sourceUrl: 'asset:plugins/engine.json');
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

    test('bundledPackUnchanged ignores enabled flags', () {
      final base = EnginePack.fromJson({
        'schema': 1,
        'name': 'Forja',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'videasy',
            'name': 'Videasy',
            'entry': 'videasy.js',
            'types': ['movie'],
            'kind': 'http',
          },
        ],
      }, sourceUrl: EngineService.bundledSourceUrl);
      final disabled = base.copyWithPlugins([
        base.plugins.first.copyWith(enabled: false),
      ]);
      expect(EngineService.bundledPackUnchanged(base, disabled), isTrue);
      final bumped = EnginePack.fromJson({
        'schema': 1,
        'name': 'Forja',
        'version': '1.0.1',
        'plugins': [
          {
            'id': 'videasy',
            'name': 'Videasy',
            'entry': 'videasy.js',
            'types': ['movie'],
            'kind': 'http',
          },
        ],
      }, sourceUrl: EngineService.bundledSourceUrl);
      expect(EngineService.bundledPackUnchanged(base, bumped), isFalse);
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

    test('All expand refetches newly selected and stale empty fetched', () {
      final streams = [
        {
          '_enginePluginId': 'videasy',
          '_addonBaseUrl': 'engine:videasy',
          'url': 'https://a.test/v',
        },
      ];
      expect(
        enginePluginIdsToRefetchOnAllExpand(
          previousSelectedIds: const {'videasy'},
          nextSelectedIds: const {'videasy', 'vidlink', 'goated'},
          fetchedIds: const {'videasy', 'vidlink', 'goated'},
          streams: streams,
        ),
        {'vidlink', 'goated'},
      );
      expect(
        engineStaleFetchedPluginIds(
          fetchedIds: const {'videasy', 'vidlink'},
          selectedIds: const {'videasy', 'vidlink'},
          streams: streams,
        ),
        {'vidlink'},
      );
    });

    test('full All selection is detected without clearing existing rows', () {
      expect(
        engineFullAllSelected(
          enabledIds: const {'videasy', 'vidlink', 'goated'},
          selectedIds: const {'videasy', 'vidlink', 'goated'},
        ),
        isTrue,
      );
      expect(
        enginePluginIdsToRefetchOnAllExpand(
          previousSelectedIds: const {'videasy'},
          nextSelectedIds: const {'videasy', 'vidlink', 'goated'},
          fetchedIds: const {'videasy'},
          streams: [
            {
              '_enginePluginId': 'videasy',
              '_addonBaseUrl': 'engine:videasy',
              'url': 'https://b.test/v',
            },
          ],
        ),
        {'vidlink', 'goated'},
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

    test('All pool is 10 desktop and 5 TV', () {
      expect(engineSourcesBatchLimit(tv: false), 10);
      expect(engineSourcesBatchLimit(tv: true), 5);
      expect(
        nextEnginePluginBatch(
          orderedIds: List<String>.generate(12, (i) => '$i'),
          selectedIds: {for (var i = 0; i < 12; i++) '$i'},
          fetchedIds: const {},
          limit: engineSourcesBatchLimit(tv: false),
        ),
        hasLength(10),
      );
      expect(
        nextEnginePluginBatch(
          orderedIds: List<String>.generate(12, (i) => '$i'),
          selectedIds: {for (var i = 0; i < 12; i++) '$i'},
          fetchedIds: const {},
          limit: engineSourcesBatchLimit(tv: true),
        ),
        hasLength(5),
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
      final jsonStr = await rootBundle.loadString('assets/plugins/engine.json');
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
          'vidsrcsbs',
          'kisskh',
          'moviebox',
          '4khdhub',
          '1shows',
          'hianime',
          'multiembed',
          'kickassanime',
          'goated',
          'meowtv',
          'peachify',
          'playimdb',
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
          'hdhub4u',
          'moviesmod',
          'uhdmovies',
          'allmovieland',
          'moviesdrive',
          'cinemacity',
          'dahmermovies',
          'kurage',
          'showbox',
          'cinevibe',
          'mallumv',
          'animepahe',
          'reanime',
          'anibd',
          'senshi',
          'animeheaven',
          'anidao',
          'aniwaves',
          'miruro',
          'megaplay',
          'animedunya',
          'anineko',
          'animegg',
          'anidbapp',
          'anikoto',
          'animenosub',
          'myflixer',
          'mkissa',
          'bingebox',
          'primesrc',
          'uflix',
          'vidnest-anime',
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
      expect(parsed.firstWhere((p) => p.id == 'vidzee').entry, 'vidzee.js');
      expect(parsed.firstWhere((p) => p.id == '2embed').entry, 'multiembed.js');
      expect(
        parsed.firstWhere((p) => p.id == 'service111477').entry,
        'dahmermovies.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'vidsrcsbs').config['nxshaOrigin'],
        'https://web.nxsha.app',
      );
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
      expect(parsed.firstWhere((p) => p.id == 'goated').entry, 'goated.js');
      expect(
        parsed.firstWhere((p) => p.id == 'goated').config['api'],
        'https://api.reallyfast.xyz',
      );
      expect(parsed.firstWhere((p) => p.id == 'meowtv').entry, 'meowtv.js');
      expect(parsed.firstWhere((p) => p.id == 'peachify').entry, 'peachify.js');
      expect(parsed.firstWhere((p) => p.id == 'playimdb').entry, 'playimdb.js');
      expect(
        parsed.firstWhere((p) => p.id == 'playimdb').config['api'],
        'https://streamdata.vaplayer.ru/api.php',
      );
      expect(parsed.firstWhere((p) => p.id == 'vidsync').entry, 'vidsync.js');
      expect(parsed.firstWhere((p) => p.id == 'vidup').entry, 'vidup.js');
      expect(parsed.firstWhere((p) => p.id == 'moviebox').entry, 'moviebox.js');
      expect(
        parsed.firstWhere((p) => p.id == 'moviebox').config['api'],
        'https://h5-api.aoneroom.com',
      );
      expect(parsed.firstWhere((p) => p.id == '4khdhub').entry, '4khdhub.js');
      expect(
        parsed.firstWhere((p) => p.id == '1shows').entry,
        'providers/1shows.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == '1shows').config['api'],
        'https://api.viduki.net',
      );
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
      expect(parsed.firstWhere((p) => p.id == 'hdhub4u').entry, 'hdhub4u.js');
      expect(
        parsed.firstWhere((p) => p.id == 'hdhub4u').config['searchApi'],
        'https://search.pingora.fyi/collections/post/documents/search',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'moviesmod').entry,
        'moviesmod.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'moviesmod').config['base'],
        'https://moviesmod.cc',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'uhdmovies').entry,
        'uhdmovies.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'uhdmovies').config['base'],
        'https://uhdmovies.pink',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'allmovieland').entry,
        'allmovieland.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'allmovieland').config['base'],
        'https://allmovieland.one',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'moviesdrive').entry,
        'moviesdrive.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'moviesdrive').config['base'],
        'https://new3.moviesdrives.my',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'cinemacity').entry,
        'cinemacity.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'cinemacity').config['base'],
        'https://cinemacity.cc',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'dahmermovies').entry,
        'dahmermovies.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'dahmermovies').config['api'],
        'https://a.111477.xyz',
      );
      expect(parsed.firstWhere((p) => p.id == 'kurage').entry, 'kurage.js');
      expect(
        parsed.firstWhere((p) => p.id == 'kurage').config['base'],
        'https://kurage.live',
      );
      expect(parsed.firstWhere((p) => p.id == 'showbox').entry, 'showbox.js');
      expect(
        parsed.firstWhere((p) => p.id == 'showbox').config['apiBase'],
        'https://id-mapping-api-showbox-proxy.hf.space/api/media',
      );
      expect(parsed.firstWhere((p) => p.id == 'cinevibe').entry, 'cinevibe.js');
      expect(
        parsed.firstWhere((p) => p.id == 'cinevibe').config['base'],
        'https://cinevibe.asia',
      );
      expect(parsed.firstWhere((p) => p.id == 'mallumv').entry, 'mallumv.js');
      expect(
        parsed.firstWhere((p) => p.id == 'mallumv').config['base'],
        'https://mallumv.gay',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animepahe').entry,
        'animepahe.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animepahe').config['proxy'],
        'https://animepaheproxy.phisheranimepahe.workers.dev/?url=',
      );
      expect(parsed.firstWhere((p) => p.id == 'reanime').entry, 'reanime.js');
      expect(
        parsed.firstWhere((p) => p.id == 'reanime').config['base'],
        'https://reanime.to',
      );
      expect(parsed.firstWhere((p) => p.id == 'anibd').entry, 'anibd.js');
      expect(
        parsed.firstWhere((p) => p.id == 'anibd').config['api'],
        'https://epeng.animeapps.top',
      );
      expect(parsed.firstWhere((p) => p.id == 'senshi').entry, 'senshi.js');
      expect(
        parsed.firstWhere((p) => p.id == 'senshi').config['base'],
        'https://senshi.live',
      );
      expect(parsed.firstWhere((p) => p.id == 'kisskh').entry, 'kisskh.js');
      expect(
        parsed.firstWhere((p) => p.id == 'kisskh').config['origin'],
        'https://kisskh.co',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animepahe').config['base'],
        'https://animepahe.pw',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animeheaven').entry,
        'animeheaven.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animeheaven').config['base'],
        'https://animeheaven.me',
      );
      expect(parsed.firstWhere((p) => p.id == 'anidao').entry, 'anidao.js');
      expect(parsed.firstWhere((p) => p.id == 'aniwaves').entry, 'aniwaves.js');
      expect(parsed.firstWhere((p) => p.id == 'miruro').entry, 'miruro.js');
      expect(
        parsed.firstWhere((p) => p.id == 'animedunya').entry,
        'animedunya.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animedunya').config['base'],
        'https://anime-dunya.com',
      );
      expect(parsed.firstWhere((p) => p.id == 'anineko').entry, 'anineko.js');
      expect(
        parsed.firstWhere((p) => p.id == 'anineko').config['base'],
        'https://anineko.to',
      );
      expect(parsed.firstWhere((p) => p.id == 'animegg').entry, 'animegg.js');
      expect(
        parsed.firstWhere((p) => p.id == 'animegg').config['base'],
        'https://www.animegg.org',
      );
      expect(parsed.firstWhere((p) => p.id == 'anidbapp').entry, 'anidbapp.js');
      expect(
        parsed.firstWhere((p) => p.id == 'anidbapp').config['base'],
        'https://anidb.app',
      );
      expect(parsed.firstWhere((p) => p.id == 'anikoto').entry, 'anikoto.js');
      expect(
        parsed.firstWhere((p) => p.id == 'anikoto').config['base'],
        'https://anikototv.to',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animenosub').entry,
        'animenosub.js',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'animenosub').config['base'],
        'https://animenosub.to',
      );
      expect(parsed.firstWhere((p) => p.id == 'myflixer').entry, 'myflixer.js');
      expect(
        parsed.firstWhere((p) => p.id == 'myflixer').config['base'],
        'https://myflixer.to',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'vidnest-anime').entry,
        'vidnest.js',
      );
      expect(
        (parsed.firstWhere((p) => p.id == 'vidnest-anime').config['servers']
                as List)
            .length,
        greaterThan(0),
      );
      expect(parsed.firstWhere((p) => p.id == 'megaplay').entry, 'megaplay.js');
      expect(
        parsed.firstWhere((p) => p.id == 'megaplay').ids,
        containsAll(['anilist', 'mal']),
      );
      expect(parsed.firstWhere((p) => p.id == 'bingebox').entry, 'embed.js');
      expect(
        parsed.firstWhere((p) => p.id == 'bingebox').config['origin'],
        'https://bingebox.ac',
      );
      expect(parsed.firstWhere((p) => p.id == 'primesrc').entry, 'embed.js');
      expect(parsed.firstWhere((p) => p.id == 'uflix').entry, 'embed.js');
      expect(parsed.firstWhere((p) => p.id == 'mycima').entry, 'catalog.js');
      expect(parsed.firstWhere((p) => p.id == 'mkissa').entry, 'mkissa.js');
      expect(
        parsed.firstWhere((p) => p.id == 'mkissa').config['api'],
        'https://api.mkissa.net',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'mkissa').config['referer'],
        'https://mkissa.to',
      );
      expect(parsed.firstWhere((p) => p.id == 'hop-abyss').isHop, isTrue);
      expect(parsed.firstWhere((p) => p.id == 'hop-megaup').isHop, isTrue);
      expect(parsed.firstWhere((p) => p.id == 'cinejoy').entry, 'cinejoy.js');
      expect(
        parsed.firstWhere((p) => p.id == 'cinejoy').config['origin'],
        'https://cinejoy.to',
      );
      expect(
        parsed.firstWhere((p) => p.id == 'cinejoy').config['api'],
        'https://api.shegu.st',
      );
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
        'assets/plugins/providers/vidrock.js',
      );
      expect(vidrock.contains('aesdec.nuvioapp.space'), isFalse);
      expect(vidrock.contains('AES.encrypt'), isFalse);
      expect(vidrock.contains('AES.decrypt'), isTrue);
      expect(vidrock.contains('mode.GCM'), isTrue);
      expect(vidrock.contains('/api/'), isTrue);
      expect(vidrock.contains('tv/'), isTrue);

      final hexa = await rootBundle.loadString(
        'assets/plugins/providers/hexa.js',
      );
      expect(hexa.contains('enc-hexa'), isTrue);
      expect(hexa.contains('X-Api-Key'), isTrue);
      expect(hexa.contains('X-Cap-Token'), isTrue);
      expect(hexa.contains('payload.sources'), isTrue);

      final vidcore = await rootBundle.loadString(
        'assets/plugins/providers/vidcore.js',
      );
      expect(vidcore.contains('enc-vidcore'), isTrue);
      expect(vidcore.contains('dec-vidcore'), isTrue);

      final hianime = await rootBundle.loadString(
        'assets/plugins/providers/hianime.js',
      );
      expect(hianime.contains('megaplay'), isTrue);
      expect(hianime.contains('getSources'), isTrue);
      expect(hianime.contains('vidtube.site'), isTrue);
      expect(hianime.contains('mewstream.buzz'), isTrue);

      final kaa = await rootBundle.loadString(
        'assets/plugins/providers/kickassanime.js',
      );
      expect(kaa.contains('/api/fsearch'), isTrue);
      expect(kaa.contains('krussdomi.com'), isTrue);

      final goated = await rootBundle.loadString(
        'assets/plugins/providers/goated.js',
      );
      expect(goated.contains('aesdec.nuvioapp.space'), isFalse);
      expect(goated.contains('/api/resolve'), isTrue);
      expect(goated.contains('/api/challenge'), isTrue);
      expect(goated.contains('solvePow'), isTrue);

      final cinejoy = await rootBundle.loadString(
        'assets/plugins/providers/cinejoy.js',
      );
      expect(cinejoy.contains('api.shegu.st'), isTrue);
      expect(cinejoy.contains('enc-cinejoy'), isTrue);
      expect(cinejoy.contains('dec-cinejoy'), isTrue);
      expect(cinejoy.contains('solveScryptPow'), isTrue);

      final meowtv = await rootBundle.loadString(
        'assets/plugins/providers/meowtv.js',
      );
      expect(meowtv.contains('/streams/'), isTrue);
      expect(meowtv.contains('dec-meowtv'), isTrue);

      final peachify = await rootBundle.loadString(
        'assets/plugins/providers/peachify.js',
      );
      expect(peachify.contains('dec-peachify'), isTrue);

      final playimdb = await rootBundle.loadString(
        'assets/plugins/providers/playimdb.js',
      );
      expect(playimdb.contains('streamdata.vaplayer.ru'), isTrue);
      expect(playimdb.contains('tmdb='), isTrue);

      final vidsync = await rootBundle.loadString(
        'assets/plugins/providers/vidsync.js',
      );
      expect(vidsync.contains('enc-vidsync'), isTrue);
      expect(vidsync.contains('dec-vidsync'), isTrue);

      final vidup = await rootBundle.loadString(
        'assets/plugins/providers/vidup.js',
      );
      expect(vidup.contains('enc-vidup'), isTrue);
      expect(vidup.contains('dec-vidup'), isTrue);

      final moviebox = await rootBundle.loadString(
        'assets/plugins/providers/moviebox.js',
      );
      expect(moviebox.contains('wefeed-h5api-bff/subject/search'), isTrue);
      expect(moviebox.contains('wefeed-h5api-bff/subject/download'), isTrue);

      final fourkhdhub = await rootBundle.loadString(
        'assets/plugins/providers/4khdhub.js',
      );
      expect(fourkhdhub.contains('HubCloud 10Gbps'), isTrue);
      expect(fourkhdhub.contains("j['4khdhub']"), isTrue);
      expect(fourkhdhub.contains('article h2 a'), isTrue);
      expect(fourkhdhub.contains('.movie-card'), isTrue);
      expect(fourkhdhub.contains(r'pixel\.hubcloud'), isTrue);
      expect(fourkhdhub.contains('pixeldrain.net/api/file/'), isTrue);
      // /drive/<id> is the HubCloud entry hop — must follow, not bail.
      expect(
        fourkhdhub.contains(
          'if (isHubCloudDrivePage(hubCloudUrl)) return Promise.resolve([])',
        ),
        isFalse,
      );

      final oneshows = await rootBundle.loadString(
        'assets/plugins/providers/1shows.js',
      );
      expect(oneshows.contains('api.viduki.net'), isTrue);
      expect(oneshows.contains('download-token'), isTrue);
      expect(oneshows.contains('decryptDownload'), isTrue);
      expect(oneshows.contains('function extract(ctx)'), isTrue);
      expect(oneshows.contains(r'pixel\.hubcloud'), isTrue);
      expect(
        oneshows.contains(
          'if (isHubCloudDrivePage(hubCloudUrl)) return Promise.resolve([])',
        ),
        isFalse,
      );

      final movieblast = await rootBundle.loadString(
        'assets/plugins/providers/movieblast.js',
      );
      expect(movieblast.contains('HmacSHA256'), isTrue);
      expect(movieblast.contains('/api/search/'), isTrue);
      expect(movieblast.contains('themoviedb.org'), isTrue);

      final streamflix = await rootBundle.loadString(
        'assets/plugins/providers/streamflix.js',
      );
      expect(streamflix.contains('/data.json'), isTrue);
      expect(streamflix.contains('config-streamflixapp.json'), isTrue);

      final animex = await rootBundle.loadString(
        'assets/plugins/providers/animex.js',
      );
      expect(animex.contains('cfg.gql'), isTrue);
      expect(animex.contains('searchAnime'), isTrue);
      expect(animex.contains('/sources'), isTrue);

      final anizone = await rootBundle.loadString(
        'assets/plugins/providers/anizone.js',
      );
      expect(anizone.contains('id-mapping-api-malid'), isTrue);
      expect(anizone.contains("media-player"), isTrue);

      final netmirror = await rootBundle.loadString(
        'assets/plugins/providers/netmirror.js',
      );
      expect(netmirror.contains('checknewtv.php'), isTrue);
      expect(netmirror.contains('embed-tmdb'), isTrue);
      expect(netmirror.contains('videodownloader.site'), isTrue);
      expect(netmirror.contains('fetchFromNetflixDirect'), isTrue);
      expect(netmirror.contains('mobidetect.art') || netmirror.contains('aHR0cHM6Ly9tb2JpZGV0ZWN0LmFydA=='), isTrue);

      final castle = await rootBundle.loadString(
        'assets/plugins/providers/castle.js',
      );
      expect(castle.contains('getSecurityKey'), isTrue);
      expect(castle.contains('film-api/v2.0.1/movie/getVideo2'), isTrue);
      expect(castle.contains('parseCastleJson'), isTrue);

      final xprime = await rootBundle.loadString(
        'assets/plugins/providers/xprime.js',
      );
      expect(xprime.contains('enc-xprime'), isTrue);
      expect(xprime.contains('dec-xprime'), isTrue);
      expect(xprime.contains('backend.xprime.tv'), isTrue);
      expect(xprime.contains("/rage?id="), isTrue);

      final dvdplay = await rootBundle.loadString(
        'assets/plugins/providers/dvdplay.js',
      );
      expect(dvdplay.contains('/search.php?q='), isTrue);
      expect(dvdplay.contains('resolveHubCloud'), isTrue);
      expect(dvdplay.contains('pixeldrain.net/api/file'), isTrue);

      final hdhub4u = await rootBundle.loadString(
        'assets/plugins/providers/hdhub4u.js',
      );
      expect(hdhub4u.contains('searchByImdb'), isTrue);
      expect(hdhub4u.contains('gadgetsweb'), isTrue);
      expect(hdhub4u.contains('hubdrive'), isTrue);
      expect(hdhub4u.contains('search.pingora.fyi'), isTrue);
      expect(hdhub4u.contains('HDHUB4u'), isTrue);
      expect(hdhub4u.contains('hubCloudExtractor'), isTrue);
      expect(hdhub4u.contains('pixeldrain.net/api/file'), isTrue);

      final moviesmod = await rootBundle.loadString(
        'assets/plugins/providers/moviesmod.js',
      );
      expect(moviesmod.contains('moviesmod'), isTrue);
      expect(moviesmod.contains('driveseed'), isTrue);
      expect(moviesmod.contains('bypassHrefli'), isTrue);

      final uhdmovies = await rootBundle.loadString(
        'assets/plugins/providers/uhdmovies.js',
      );
      expect(uhdmovies.contains('UHDMovies'), isTrue);
      expect(uhdmovies.contains('extractDriveseed'), isTrue);
      expect(uhdmovies.contains('extractVideoSeed'), isTrue);

      final allmovieland = await rootBundle.loadString(
        'assets/plugins/providers/allmovieland.js',
      );
      expect(allmovieland.contains('allmovieland'), isTrue);
      expect(allmovieland.contains('AwsIndStreamDomain'), isTrue);
      expect(allmovieland.contains('X-CSRF-TOKEN'), isTrue);

      final moviesdrive = await rootBundle.loadString(
        'assets/plugins/providers/moviesdrive.js',
      );
      expect(moviesdrive.contains('moviesdrive'), isTrue);
      expect(moviesdrive.contains('hubCloudExtract'), isTrue);
      expect(moviesdrive.contains('/search.php?q='), isTrue);

      final cinemacity = await rootBundle.loadString(
        'assets/plugins/providers/cinemacity.js',
      );
      expect(cinemacity.contains('dar-short_item'), isTrue);
      expect(cinemacity.contains('atob'), isTrue);

      final dahmermovies = await rootBundle.loadString(
        'assets/plugins/providers/dahmermovies.js',
      );
      expect(dahmermovies.contains('a.111477.xyz'), isTrue);
      // CF beacon `/cdn-cgi/challenge-platform/` must not alone abort listings.
      expect(dahmermovies.contains('challenge-platform|'), isFalse);
      expect(dahmermovies.contains('you are being rate limited'), isTrue);

      final kurage = await rootBundle.loadString(
        'assets/plugins/providers/kurage.js',
      );
      expect(kurage.contains('graphql.anilist.co'), isTrue);
      expect(kurage.contains('/api/trpc/'), isTrue);

      final showbox = await rootBundle.loadString(
        'assets/plugins/providers/showbox.js',
      );
      expect(showbox.contains('febbox.com'), isTrue);
      expect(showbox.contains('TripleDES'), isTrue);

      final cinevibe = await rootBundle.loadString(
        'assets/plugins/providers/cinevibe.js',
      );
      expect(cinevibe.contains('/api/stream/fetch'), isTrue);
      expect(cinevibe.contains('X-CV-Fingerprint'), isTrue);

      final mallumv = await rootBundle.loadString(
        'assets/plugins/providers/mallumv.js',
      );
      expect(mallumv.contains('search.php?q='), isTrue);
      expect(mallumv.contains('extractHubCloudLinks'), isTrue);
      expect(mallumv.contains('function extract(ctx)'), isTrue);

      final animepahe = await rootBundle.loadString(
        'assets/plugins/providers/animepahe.js',
      );
      expect(animepahe.contains('animepaheproxy'), isTrue);
      expect(animepahe.contains('extractKwik'), isTrue);
      expect(animepahe.contains('kwik.si'), isTrue);
      expect(animepahe.contains('id-mapping-api-malid'), isTrue);
      expect(animepahe.contains("ctx.type === 'anime'"), isTrue);
      expect(animepahe.contains('resolveMal'), isTrue);

      final reanime = await rootBundle.loadString(
        'assets/plugins/providers/reanime.js',
      );
      expect(reanime.contains('reanime.to'), isTrue);
      expect(reanime.contains('flixcloud.cc'), isTrue);
      expect(reanime.contains('ctx.hop'), isTrue);

      final anibd = await rootBundle.loadString(
        'assets/plugins/providers/anibd.js',
      );
      expect(anibd.contains('api2.php?epid='), isTrue);
      expect(anibd.contains('apilink.php'), isTrue);
      expect(anibd.contains('videoUrl'), isTrue);

      final senshi = await rootBundle.loadString(
        'assets/plugins/providers/senshi.js',
      );
      expect(senshi.contains('senshi.live'), isTrue);
      expect(senshi.contains('episode-embeds'), isTrue);
      expect(senshi.contains('embedType'), isTrue);

      final kisskh = await rootBundle.loadString(
        'assets/plugins/providers/kisskh.js',
      );
      expect(kisskh.contains('kisskh.co'), isTrue);
      expect(kisskh.contains('tryOnce'), isTrue);
      expect(kisskh.contains('dramaId'), isTrue);
      expect(kisskh.contains('if (episodeId)'), isTrue);

      final animedunya = await rootBundle.loadString(
        'assets/plugins/providers/animedunya.js',
      );
      expect(animedunya.contains('anime-dunya.com'), isTrue);
      expect(animedunya.contains('/en/play/'), isTrue);

      final anineko = await rootBundle.loadString(
        'assets/plugins/providers/anineko.js',
      );
      expect(anineko.contains('nv-server-grid'), isTrue);
      expect(anineko.contains('browser?keyword='), isTrue);

      final animegg = await rootBundle.loadString(
        'assets/plugins/providers/animegg.js',
      );
      expect(animegg.contains('videoSources'), isTrue);
      expect(animegg.contains('/search/?q='), isTrue);

      final anidbapp = await rootBundle.loadString(
        'assets/plugins/providers/anidbapp.js',
      );
      expect(anidbapp.contains('/api/frontend/anime/'), isTrue);
      expect(anidbapp.contains('/api/frontend/episode/'), isTrue);

      final anikoto = await rootBundle.loadString(
        'assets/plugins/providers/anikoto.js',
      );
      expect(anikoto.contains('anikototv.to'), isTrue);
      expect(anikoto.contains('/ajax/episode/list/'), isTrue);
      expect(anikoto.contains('getSources'), isTrue);
      expect(anikoto.contains('mewstream.buzz'), isTrue);
      expect(anikoto.contains('mapper.mewcdn.online'), isTrue);

      final animeheaven = await rootBundle.loadString(
        'assets/plugins/providers/animeheaven.js',
      );
      expect(animeheaven.contains('gate.php'), isTrue);
      expect(animeheaven.contains('fastsearch.php'), isTrue);

      final anidao = await rootBundle.loadString(
        'assets/plugins/providers/anidao.js',
      );
      expect(anidao.contains('anidao.to'), isTrue);
      expect(anidao.contains('data-an-video'), isTrue);

      final aniwaves = await rootBundle.loadString(
        'assets/plugins/providers/aniwaves.js',
      );
      expect(aniwaves.contains('aniwaves.ru'), isTrue);
      expect(aniwaves.contains('/ajax/sources'), isTrue);

      final miruro = await rootBundle.loadString(
        'assets/plugins/providers/miruro.js',
      );
      expect(miruro.contains('api/secure/pipe'), isTrue);
      expect(miruro.contains('decodePipe'), isTrue);
      expect(miruro.contains('x-obfuscated'), isTrue);
      expect(miruro.contains('episodeId: String(ep.id)'), isTrue);
      expect(miruro.contains('encodeReq(String(ep.id))'), isFalse);

      final megaplay = await rootBundle.loadString(
        'assets/plugins/providers/megaplay.js',
      );
      expect(megaplay.contains('/stream/ani/'), isTrue);
      expect(megaplay.contains('getSources'), isTrue);

      final vidnest = await rootBundle.loadString(
        'assets/plugins/providers/vidnest.js',
      );
      expect(vidnest.contains('/anime/'), isTrue);
      expect(vidnest.contains("ctx.type === 'anime'"), isTrue);

      final animenosub = await rootBundle.loadString(
        'assets/plugins/providers/animenosub.js',
      );
      expect(animenosub.contains('admin-ajax.php'), isTrue);
      expect(animenosub.contains('animenosub.to'), isTrue);

      final myflixer = await rootBundle.loadString(
        'assets/plugins/providers/myflixer.js',
      );
      expect(myflixer.contains('/search/'), isTrue);
      expect(myflixer.contains('ctx.hop'), isTrue);

      final mkissa = await rootBundle.loadString(
        'assets/plugins/providers/mkissa.js',
      );
      expect(mkissa.contains('api.mkissa.net'), isTrue);
      expect(mkissa.contains('client-crypto/v1/bootstrap'), isTrue);
      expect(mkissa.contains('aaReq'), isTrue);
      expect(mkissa.contains('handleWatch'), isTrue);
    });

    test('1shows plugin is wired in the pack', () async {
      final jsonStr = await rootBundle.loadString('assets/plugins/engine.json');
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plugins = map['plugins'] as List;
      final oneshows = EnginePlugin.fromJson(
        Map<String, dynamic>.from(
          plugins.cast<Map>().firstWhere((p) => p['id'] == '1shows') as Map,
        ),
      );
      expect(oneshows.entry, 'providers/1shows.js');
      expect(oneshows.config['api'], 'https://api.viduki.net');
      expect(oneshows.types, containsAll(['movie', 'tv']));
      final src = await rootBundle.loadString(
        'assets/plugins/providers/1shows.js',
      );
      expect(src.contains('function extract(ctx)'), isTrue);
      expect(src.contains('download-token'), isTrue);
      expect(src.contains('decryptDownload'), isTrue);
      expect(src.contains('api.viduki.net'), isTrue);
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
      final src = await rootBundle.loadString(
        'assets/plugins/providers/videasy.js',
      );
      expect(src, contains('ctx.config'));
      expect(src, contains('cfg.mirrors'));
      expect(src, contains('mirror.endpoint'));
      expect(src, contains('mirror.name'));
      expect(src, contains('Promise.all'));
      expect(src, contains('preferHlsMaster'));
      expect(src, contains('quality:'));
      expect(src, contains('language:'));
      expect(src, contains('ctx.crypto.streamDecrypt'));
      final jsonStr = await rootBundle.loadString('assets/plugins/engine.json');
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
      final jsonStr = await rootBundle.loadString('assets/plugins/engine.json');
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

    test('engine.json tags movie/tv, anime, and drama categories', () async {
      final jsonStr = await rootBundle.loadString('assets/plugins/engine.json');
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final plugins = [
        for (final p in map['plugins'] as List)
          EnginePlugin.fromJson(Map<String, dynamic>.from(p as Map)),
      ];
      EnginePlugin byId(String id) => plugins.firstWhere((p) => p.id == id);
      expect(byId('videasy').types, ['movie', 'tv', 'drama']);
      expect(byId('vidlink').types, ['movie', 'tv', 'drama']);
      expect(byId('vixsrc').types, ['movie', 'tv', 'drama']);
      expect(byId('vidnest').types, ['movie', 'tv', 'drama']);
      expect(byId('vidrock').types, ['movie', 'tv', 'drama']);
      expect(byId('vidsrcsbs').types, ['movie', 'tv', 'drama']);
      expect(byId('2embed').types, ['movie', 'tv', 'drama']);
      expect(byId('multiembed').types, ['movie', 'tv', 'drama']);
      expect(byId('kisskh').types, ['drama']);
      expect(byId('hianime').types, ['anime']);
      expect(
        EngineCategories.panelCategoryFromPlayingPlugin(byId('videasy')),
        isNull,
      );
      expect(
        EngineCategories.panelCategoryFromPlayingPlugin(byId('kisskh')),
        EngineCategories.drama,
      );
      expect(
        EngineCategories.panelCategoryFromPlayingPlugin(byId('hianime')),
        EngineCategories.anime,
      );
      expect(EngineCategories.defaultsForMediaType('movie'), {
        EngineCategories.movie,
      });
      expect(
        EngineCategories.panelCategoryFor(
          mediaType: 'tv',
          panelCategory: 'anime',
        ),
        EngineCategories.anime,
      );
      expect(
        EngineCategories.panelCategoryFor(mediaType: 'movie'),
        EngineCategories.movie,
      );
      expect(
        EngineCategories.panelCategoryFor(mediaType: 'asian_drama'),
        EngineCategories.drama,
      );
      expect(
        EngineCategories.pluginChipVisible(
          plugin: byId('hianime'),
          visibleCategories: {EngineCategories.movie},
          selectedPluginIds: const {},
        ),
        isFalse,
      );
      expect(
        EngineCategories.pluginChipVisible(
          plugin: byId('hianime'),
          visibleCategories: {EngineCategories.movie},
          selectedPluginIds: {'hianime'},
        ),
        isTrue,
      );
    });

    test(
      'engine.json ships live sports plugins separate from VOD Sources',
      () async {
        final jsonStr = await rootBundle.loadString(
          'assets/plugins/engine.json',
        );
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final plugins = [
          for (final p in map['plugins'] as List)
            EnginePlugin.fromJson(Map<String, dynamic>.from(p as Map)),
        ];
        const liveSportIds = [
          'live-timstreams',
          'live-streamfree',
          'live-watchfooty',
          'live-streamic',
        ];
        for (final id in liveSportIds) {
          final p = plugins.firstWhere((e) => e.id == id);
          expect(p.isLiveSport, isTrue);
          expect(p.isVodCatalog, isFalse);
          expect(p.entry.startsWith('live/'), isTrue);
        }
        for (final id in ['live-streamed', 'live-ppv']) {
          final p = plugins.firstWhere((e) => e.id == id);
          expect(p.isLivePlugin, isTrue);
          expect(p.isVodCatalog, isFalse);
        }
        const catalogIds = [
          'catalog-streamed',
          'catalog-ppv',
          'catalog-timstreams',
          'catalog-streamfree',
          'catalog-watchfooty',
          'catalog-streamic',
          'catalog-espn',
        ];
        for (final id in catalogIds) {
          final p = plugins.firstWhere((e) => e.id == id);
          expect(p.isLiveCatalog, isTrue);
          expect(p.entry.startsWith('catalog/'), isTrue);
          expect(p.entry.endsWith('.js'), isTrue);
        }
        expect(
          await rootBundle.loadString('assets/plugins/catalog/timstreams.js'),
          contains('function extract(ctx)'),
        );
        expect(
          await rootBundle.loadString('assets/plugins/catalog/streamed.js'),
          contains('/api/matches/all'),
        );
        expect(
          await rootBundle.loadString('assets/plugins/catalog/ppv.js'),
          contains('api.ppv.st'),
        );
        for (final id in ['live-streamed', 'live-ppv', 'live-timstreams']) {
          final p = plugins.firstWhere((e) => e.id == id);
          final src = await rootBundle.loadString('assets/plugins/${p.entry}');
          expect(src, contains('action !== \'resolve\') return []'));
        }
        expect(
          await rootBundle.loadString('assets/plugins/catalog/espn.js'),
          contains('LEAGUE_ENDPOINTS'),
        );
      },
    );

    test('vidnest.js uses the Forja custom-alphabet cipher', () async {
      final src = await rootBundle.loadString(
        'assets/plugins/providers/vidnest.js',
      );
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
          'assets/plugins/providers/hops/$name.js',
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
        final src = await rootBundle.loadString(
          'assets/plugins/providers/vidlink.js',
        );
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
        final src = await rootBundle.loadString(
          'assets/plugins/providers/vixsrc.js',
        );
        expect(src, contains('ctx.config'));
        expect(src, contains('/api/tv/'));
        expect(src, contains('/api/movie/'));
        expect(src, contains('parseM3u8Variants'));
        expect(src, contains('TYPE=AUDIO'));
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

    test('folds HubCloud release title into description for badges', () {
      final mapped = mapEngineStream(
        raw: {
          'url': 'https://cdn.example/file.mkv',
          'name': 'HDHub4u FSL',
          'title':
              'Obsession.2026.2160p.BluRay.HEVC.Atmos.HDR.mkv',
          'quality': '4K',
          'size': '51.93 GB',
        },
        plugin: plugin,
        mediaTitle: 'Obsession',
        year: '2026',
        type: 'movie',
      )!;
      expect(mapped['title'], 'Obsession - (2026)');
      expect(mapped['size'], '51.93 GB');
      expect(mapped['container'], 'MKV');
      expect(
        mapped['description'],
        contains('Obsession.2026.2160p.BluRay.HEVC.Atmos.HDR.mkv'),
      );
      expect(mapped['description'], contains('4K'));
      expect(mapped['description'], contains('MKV'));
      expect(mapped['description'], contains('51.93 GB'));
    });

    test('reads size from release title when size field is missing', () {
      final mapped = mapEngineStream(
        raw: {
          'url': 'https://cdn.example/a.mp4',
          'name': '4KHDHub',
          'title': 'Show.2024.1080p.WEB-DL.x264 [14.2 GB]',
          'quality': '1080p',
        },
        plugin: plugin,
        mediaTitle: 'Show',
        year: '2024',
        type: 'movie',
      )!;
      expect(mapped['size'], '14.2 GB');
      expect(mapped['container'], 'MP4');
    });

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
      expect(mapped['description'], contains('Vidlink · 1080p'));
      expect(mapped['description'], contains('1080p'));
      expect(mapped['_addonName'], 'Videasy · Vidlink');
    });

    test('Megaplay bracket names avoid plugin duplication', () {
      final megaplay = EnginePlugin.fromJson({
        'id': 'megaplay',
        'name': 'Megaplay',
        'entry': 'megaplay.js',
        'kind': 'http',
      });
      final sameServer = mapEngineStream(
        raw: {
          'url': 'https://cdn.example/a.m3u8',
          'name': 'Megaplay [MegaPlay] (SUB)',
          'language': 'Sub',
        },
        plugin: megaplay,
        mediaTitle: 'Slime',
        type: 'anime',
        season: 1,
        episode: 4,
        year: '2018',
      )!;
      expect(sameServer['_addonName'], 'Megaplay');

      final altServer = mapEngineStream(
        raw: {
          'url': 'https://cdn.example/b.m3u8',
          'name': 'Megaplay [Vidwish] (SUB)',
          'language': 'Sub',
        },
        plugin: megaplay,
        mediaTitle: 'Slime',
        type: 'anime',
        season: 1,
        episode: 4,
        year: '2018',
      )!;
      expect(altServer['_addonName'], 'Megaplay · Vidwish');
    });
  });

  group('engineStreamAudioCategory', () {
    test('reads language field and (SUB)/(DUB) in name', () {
      expect(engineStreamAudioCategory({'language': 'Dub'}), 'dub');
      expect(
        engineStreamAudioCategory({'name': 'Megaplay [Vidwish] (SUB)'}),
        'sub',
      );
      expect(engineStreamAudioCategory({'name': 'Stream'}), isNull);
    });

    test('engineStreamMatchesAudioCategory filters sub/dub rows', () {
      final row = {'language': 'Sub', 'name': 'Megaplay [MegaPlay] (SUB)'};
      expect(engineStreamMatchesAudioCategory(row, 'sub'), isTrue);
      expect(engineStreamMatchesAudioCategory(row, 'dub'), isFalse);
      expect(
        engineStreamMatchesAudioCategory({'name': 'Plain'}, 'sub'),
        isTrue,
      );
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

    test('extract(ctx) receives resolved anime ids', () async {
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'ctx-anime-ids',
        code: '''
function extract(ctx) {
  return Promise.resolve([{
    url: 'https://cdn.example/anime.m3u8',
    title: ctx.malId + ':' + ctx.anilistId + ':' + ctx.mappedEpisode
  }]);
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'ctx-anime-ids',
        tmdbId: '99',
        malId: 5114,
        anilistId: 21,
        mappedEpisode: 3,
        type: 'tv',
        season: 1,
        episode: 3,
      );
      expect(streams.single['title'], '5114:21:3');
    });

    test('ctx.crypto encodePipe / decodePipe round-trip JSON', () async {
      final rt = EngineRuntime.instance;
      await rt.loadPlugin(
        pluginId: 'pipe-codec',
        code: '''
function extract(ctx) {
  var enc = ctx.crypto.encodePipe({ path: 'episodes', query: { anilistId: 21 } });
  var raw = '{"streams":[{"url":"https://cdn.example/a.m3u8","type":"hls"}]}';
  var dec = ctx.crypto.decodePipe(raw, '');
  return Promise.resolve([{
    url: dec.streams[0].url,
    title: enc.indexOf('=') >= 0 ? 'padded' : 'b64url'
  }]);
}
''',
      );
      final streams = await rt.extract(
        pluginId: 'pipe-codec',
        tmdbId: '1',
        type: 'tv',
        episode: 1,
      );
      expect(streams.single['url'], 'https://cdn.example/a.m3u8');
      expect(streams.single['title'], 'b64url');
    });

    test('EnginePlugin parses ids manifest field', () {
      final p = EnginePlugin.fromJson({
        'id': 'animepahe',
        'name': 'AnimePahe',
        'entry': 'animepahe.js',
        'ids': ['title', 'mal'],
      });
      expect(p.ids, ['title', 'mal']);
      expect(EngineAnimeIds.pluginNeedsResolve(p), isTrue);
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
