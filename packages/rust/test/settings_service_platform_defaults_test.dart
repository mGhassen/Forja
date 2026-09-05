import 'dart:convert';
import 'dart:io';

import 'helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

/// Pre–RFC-081 rail (hub packs in platform defaults). Legacy shell migrations
/// still rewrite *to* this list — not host-only [PlatformDefaults.defaultNavIds].
const _legacyPackSeededDefaultNavIds = [
  'home',
  'asian_drama',
  'anime',
  'iptv',
  'live_matches',
  'mylist',
];

void main() {
  late Directory tmp;
  var storeCounter = 0;

  Future<void> openFreshStore() async {
    final path = '${tmp.path}/store_${storeCounter++}.json';
    final open =
        jsonDecode(RustLib.instance.storageOpen(path)) as Map<String, dynamic>;
    expect(open['ok'], isTrue);
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initRustForTests();
    await Engine.init(
      storagePath: '${Directory.systemTemp.path}/forja_seed_init.json',
    );
    tmp = await Directory.systemTemp.createTemp('forja_settings_seed_');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  setUp(() async {
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    await openFreshStore();
  });

  test('fresh Android TV install seeds nav and player defaults', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

    final nav = await service.getNavbarConfig();
    expect(nav, PlatformDefaults.androidTvNavIds);

    expect(await service.getExternalPlayer(), 'Built-in Player');
    expect(
      await service.getBuiltInPlayerEngine(),
      BuiltInPlayerEngine.mediaKit,
    );
    expect(await service.getSubSize(), 52);
    expect(await service.getSubBottomPadding(), 48);
    expect(await service.getTorrentDiskCacheGb(), 1);
      expect(await service.isPlaySourceWebstreamingEnabled(), isFalse);
      expect(await service.isPlaySourceTorrentEnabled(), isFalse);
      expect(await service.isPlaySourceStremioEnabled(), isFalse);
      expect(await service.isPlaySourceNuvioEnabled(), isFalse);
      expect(await service.isPlaySourceEngineEnabled(), isTrue);
      expect(await service.isPlaySourceEngineAutoStartEnabled(), isTrue);
  });

  test(
    'ATV unset IPTV engine stays MediaKit when VOD is Exo; Live stays MediaKit',
    () async {
      addTearDown(() {
        SettingsService.configurePlatformProfile(PlatformProfile.phone);
      });
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      final service = SettingsService();
      // Mark MediaKit-default migration done so an explicit Exo pick sticks.
      await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
      await service.setBuiltInPlayerEngine(
        BuiltInPlayerEngine.exoPlayer,
        context: BuiltInPlayerContext.vod,
      );
      expect(
        await service.getBuiltInPlayerEngine(
          context: BuiltInPlayerContext.vod,
        ),
        BuiltInPlayerEngine.exoPlayer,
      );
      expect(
        await service.getBuiltInPlayerEngine(
          context: BuiltInPlayerContext.iptv,
        ),
        BuiltInPlayerEngine.mediaKit,
      );
      expect(
        await service.getBuiltInPlayerEngine(
          context: BuiltInPlayerContext.live,
        ),
        BuiltInPlayerEngine.mediaKit,
      );
    },
  );

  test('legacy Exo VOD/IPTV migrate once to MediaKit default', () async {
    await kvSetString(
      BuiltInPlayerContext.vod.storageKey,
      BuiltInPlayerEngine.exoPlayer.storageKey,
    );
    await kvSetString(
      BuiltInPlayerContext.iptv.storageKey,
      BuiltInPlayerEngine.exoPlayer.storageKey,
    );
    await kvSetString(
      BuiltInPlayerContext.live.storageKey,
      BuiltInPlayerEngine.exoPlayer.storageKey,
    );
    // Pretend an older install already seeded platform defaults.
    await kvSetString('platform_defaults_seeded_v1', 'androidTv');

    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

    expect(
      await service.getBuiltInPlayerEngine(
        context: BuiltInPlayerContext.vod,
      ),
      BuiltInPlayerEngine.mediaKit,
    );
    expect(
      await service.getBuiltInPlayerEngine(
        context: BuiltInPlayerContext.iptv,
      ),
      BuiltInPlayerEngine.mediaKit,
    );
    // Live was an explicit Exo pick — leave alone.
    expect(
      await service.getBuiltInPlayerEngine(
        context: BuiltInPlayerContext.live,
      ),
      BuiltInPlayerEngine.exoPlayer,
    );

    await service.setBuiltInPlayerEngine(
      BuiltInPlayerEngine.exoPlayer,
      context: BuiltInPlayerContext.vod,
    );
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
    expect(
      await service.getBuiltInPlayerEngine(
        context: BuiltInPlayerContext.vod,
      ),
      BuiltInPlayerEngine.exoPlayer,
    );
  });

  test(
    'Android TV play sources honor stored prefs',
    () async {
      addTearDown(() {
        PlatformPlayback.clearOverride();
        SettingsService.configurePlatformProfile(PlatformProfile.phone);
      });
      PlatformPlayback.override = PlaybackProfile.androidTv;
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);

      final service = SettingsService();
      await service.setPlaySourceTorrentEnabled(true);
      await service.setPlaySourceStremioEnabled(true);
      await service.setPlaySourceNuvioEnabled(true);

      expect(await service.isPlaySourceTorrentStored(), isTrue);
      expect(await service.isPlaySourceStremioStored(), isTrue);
      expect(await service.isPlaySourceNuvioStored(), isTrue);
      expect(await service.isPlaySourceTorrentEnabled(), isTrue);
      expect(await service.isPlaySourceStremioEnabled(), isTrue);
      expect(await service.isPlaySourceNuvioEnabled(), isTrue);
      expect(PlatformPlayback.capabilities.playSourceTorrent, isTrue);
      expect(PlatformPlayback.capabilities.playSourceStremio, isTrue);
      expect(PlatformPlayback.capabilities.playSourceNuvio, isTrue);
    },
  );

  test('P2P acknowledgement defaults off and persists', () async {
    final service = SettingsService();
    expect(await service.isP2pStreamingAcknowledged(), isFalse);
    await service.setP2pStreamingAcknowledged(true);
    expect(await service.isP2pStreamingAcknowledged(), isTrue);
    await service.setP2pStreamingAcknowledged(false);
    expect(await service.isP2pStreamingAcknowledged(), isFalse);
  });

  test('fresh phone install seeds phone nav defaults', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.phone);

    final nav = await service.getNavbarConfig();
    expect(nav, ['iptv']);
    expect(await service.getSubSize(), 24);
    expect(await service.getTorrentDiskCacheGb(), 1);
  });

  test('fresh desktop install seeds desktop subtitle default', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.desktop);

    expect(await service.getSubSize(), 44);
    expect(await service.getNavbarConfig(), PlatformDefaults.phoneNavIds);
    expect(await service.getPlayInBackground(), isTrue);
    expect(await service.getTorrentDiskCacheGb(), 2);
  });

  test('fresh Android TV install pauses in background by default', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

    expect(await service.getPlayInBackground(), isFalse);
  });

  test(
    'ATV catalog play sources migration enables Forja only',
    () async {
      addTearDown(() {
        SettingsService.configurePlatformProfile(PlatformProfile.phone);
      });
      await kvSetBool('play_source_torrent_enabled', false);
      await kvSetBool('play_source_stremio_enabled', false);
      await kvSetBool('play_source_nuvio_enabled', false);
      await kvSetBool('play_source_engine_enabled', false);
      await kvSetString('platform_defaults_seeded_v1', 'androidTv');
      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);

      final service = SettingsService();
      await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

      expect(await service.isPlaySourceTorrentEnabled(), isFalse);
      expect(await service.isPlaySourceStremioEnabled(), isFalse);
      expect(await service.isPlaySourceNuvioEnabled(), isFalse);
      expect(await service.isPlaySourceEngineEnabled(), isTrue);
    },
  );

  test(
    'ATV resets cloud-polluted play_in_background and always pauses',
    () async {
      await kvSetBool('play_in_background', true);
      await kvSetString('platform_defaults_seeded_v1', 'androidTv');
      await kvSetStringList('navbar_config', const ['home', 'iptv']);
      await kvSetStringList(
        'navbar_known_ids',
        List.from(SettingsService.allNavIds),
      );

      final service = SettingsService();
      await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

      expect(await service.getPlayInBackground(), isFalse);
      expect(SettingsService.keepsPlayingInBackground, isFalse);

      // Migration is one-shot; stored value can change but ATV still pauses.
      await kvSetBool('play_in_background', true);
      await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
      expect(await service.getPlayInBackground(), isTrue);
      expect(SettingsService.keepsPlayingInBackground, isFalse);
    },
  );

  test('ensurePlatformDefaultsSeeded is idempotent', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
    await kvSetStringList('navbar_config', const ['home']);

    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

    final nav = await service.getNavbarConfig();
    expect(nav, ['home']);
  });

  test('legacy install with navbar config is not overwritten', () async {
    await kvSetStringList('navbar_config', const ['home', 'iptv']);
    await kvSetStringList(
      'navbar_known_ids',
      List.from(SettingsService.allNavIds),
    );
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');

    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

    final nav = await service.getNavbarConfig();
    expect(nav, contains('home'));
    expect(nav, contains('iptv'));
    expect(nav.indexOf('home'), lessThan(nav.indexOf('iptv')));
  });

  test(
    'legacy untouched nav defaults migrate to the current default',
    () async {
      await kvSetStringList('navbar_config', const [
        'home',
        'search',
        'mylist',
      ]);
      await kvSetStringList(
        'navbar_known_ids',
        List.from(SettingsService.allNavIds),
      );
      await kvSetString('navbar_shell_080', '1');
      await kvSetString('navbar_shell_081', '1');
      await kvSetString('navbar_shell_084', '1');
      await kvSetString('navbar_shell_085', '1');
      await kvSetString('navbar_shell_086', '1');
      await kvSetString('navbar_shell_087', '1');
      await kvSetString('navbar_shell_088', '1');

      final nav = await SettingsService().getNavbarConfig();

      expect(nav, _legacyPackSeededDefaultNavIds);
    },
  );

  test('Android TV legacy nav migrates to pack-seeded default', () async {
    await kvSetStringList('navbar_config', const [
      'home',
      'search',
      'anime',
      'asian_drama',
      'iptv',
      'live_matches',
      'mylist',
    ]);
    await kvSetStringList(
      'navbar_known_ids',
      List.from(SettingsService.allNavIds),
    );
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');
    await kvSetString('navbar_shell_084', '1');
    await kvSetString('navbar_shell_085', '1');
    await kvSetString('navbar_shell_086', '1');
    await kvSetString('navbar_shell_087', '1');

    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    final service = SettingsService();
    final nav = await service.getNavbarConfig();

    expect(nav, _legacyPackSeededDefaultNavIds);
  });

  test('Android TV custom nav is not overwritten by shell 088', () async {
    await kvSetStringList('navbar_config', const ['home', 'iptv', 'search']);
    await kvSetStringList(
      'navbar_known_ids',
      List.from(SettingsService.allNavIds),
    );
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');
    await kvSetString('navbar_shell_084', '1');
    await kvSetString('navbar_shell_085', '1');
    await kvSetString('navbar_shell_086', '1');
    await kvSetString('navbar_shell_087', '1');

    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    final service = SettingsService();
    final nav = await service.getNavbarConfig();

    expect(nav, ['home', 'iptv', 'search']);
  });

  test('Android TV search-first legacy migrates to pack-seeded default', () async {
    await kvSetStringList('navbar_config', const [
      'search',
      'home',
      'anime',
      'asian_drama',
      'iptv',
      'live_matches',
      'mylist',
    ]);
    await kvSetStringList(
      'navbar_known_ids',
      List.from(SettingsService.allNavIds),
    );
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');
    await kvSetString('navbar_shell_084', '1');
    await kvSetString('navbar_shell_085', '1');

    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    final service = SettingsService();
    final nav = await service.getNavbarConfig();

    expect(nav, _legacyPackSeededDefaultNavIds);
  });

  test(
    'Android TV anime-before-asian legacy migrates once shell 088 applied',
    () async {
      await kvSetStringList('navbar_config', const [
        'search',
        'home',
        'anime',
        'asian_drama',
        'iptv',
        'live_matches',
        'mylist',
      ]);
      await kvSetStringList(
        'navbar_known_ids',
        List.from(SettingsService.allNavIds),
      );
      await kvSetString('navbar_shell_080', '1');
      await kvSetString('navbar_shell_081', '1');
      await kvSetString('navbar_shell_084', '1');
      await kvSetString('navbar_shell_085', '1');
      await kvSetString('navbar_shell_086', '1');
      await kvSetString('navbar_shell_087', '1');
      await kvSetString('navbar_shell_088', '1');

      SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
      final service = SettingsService();
      final nav = await service.getNavbarConfig();

      expect(nav, _legacyPackSeededDefaultNavIds);
    },
  );

  test(
    'Android TV anime-before-asian migrates after shell 089 when shell 090 pending',
    () async {
      await kvSetStringList('navbar_config', const [
        'search',
        'home',
        'anime',
        'asian_drama',
        'iptv',
        'live_matches',
        'mylist',
      ]);
      await kvSetStringList(
        'navbar_known_ids',
        List.from(SettingsService.allNavIds),
      );
      await kvSetString('navbar_shell_080', '1');
      await kvSetString('navbar_shell_081', '1');
      await kvSetString('navbar_shell_084', '1');
      await kvSetString('navbar_shell_085', '1');
      await kvSetString('navbar_shell_086', '1');
      await kvSetString('navbar_shell_087', '1');
      await kvSetString('navbar_shell_088', '1');
      await kvSetString('navbar_shell_089', '1');

      final nav = await SettingsService().getNavbarConfig();

      expect(nav, _legacyPackSeededDefaultNavIds);
    },
  );

  test('desktop legacy search-first nav migrates to pack-seeded default', () async {
    await kvSetStringList('navbar_config', const ['search', 'home', 'mylist']);
    await kvSetStringList(
      'navbar_known_ids',
      List.from(SettingsService.allNavIds),
    );
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');
    await kvSetString('navbar_shell_084', '1');
    await kvSetString('navbar_shell_085', '1');
    await kvSetString('navbar_shell_086', '1');

    SettingsService.configurePlatformProfile(PlatformProfile.desktop);
    final service = SettingsService();
    final nav = await service.getNavbarConfig();

    expect(nav, _legacyPackSeededDefaultNavIds);
  });

  test(
    'shell 091 migrates previous default that included Search',
    () async {
      await kvSetStringList('navbar_config', const [
        'search',
        'home',
        'asian_drama',
        'anime',
        'iptv',
        'live_matches',
        'mylist',
      ]);
      await kvSetStringList(
        'navbar_known_ids',
        List.from(SettingsService.allNavIds),
      );
      await kvSetString('navbar_shell_080', '1');
      await kvSetString('navbar_shell_081', '1');
      await kvSetString('navbar_shell_084', '1');
      await kvSetString('navbar_shell_085', '1');
      await kvSetString('navbar_shell_086', '1');
      await kvSetString('navbar_shell_087', '1');
      await kvSetString('navbar_shell_088', '1');
      await kvSetString('navbar_shell_089', '1');
      await kvSetString('navbar_shell_090', '1');

      final nav = await SettingsService().getNavbarConfig();

      expect(nav, _legacyPackSeededDefaultNavIds);
      expect(nav, isNot(contains('search')));
    },
  );

  test('default nav tab persists and resolves startup index', () async {
    final service = SettingsService();
    await service.setDefaultNavTab('iptv');
    expect(await service.getDefaultNavTab(), 'iptv');

    final visible = ['home', 'search', 'iptv', 'settings'];
    expect(
      SettingsService.initialShellTabIndex(visible, defaultTabId: 'iptv'),
      2,
    );
    expect(
      SettingsService.initialShellTabIndex(visible, defaultTabId: 'missing'),
      0,
    );
  });

  test('iptv live buffer secs normalize + demuxer profiles', () {
    expect(SettingsService.normalizeIptvLiveBufferSecs(null), 0);
    expect(SettingsService.normalizeIptvLiveBufferSecs(0), 0);
    expect(SettingsService.normalizeIptvLiveBufferSecs(15), 15);
    expect(SettingsService.normalizeIptvLiveBufferSecs(20), 20);
    expect(SettingsService.normalizeIptvLiveBufferSecs(30), 30);
    expect(SettingsService.normalizeIptvLiveBufferSecs(25), 0);
    expect(SettingsService.normalizeIptvLiveBufferSecs(60), 0);

    expect(
      SettingsService.iptvLiveBufferSecsLabel(0),
      'Auto (by resolution)',
    );
    expect(SettingsService.iptvLiveBufferSecsLabel(30), '30 seconds');

    final p15 = SettingsService.iptvLiveBufferProfileForSecs(15);
    expect(p15.cacheSecs, 15);
    expect(p15.demuxerMaxBytes, 48 * 1024 * 1024);

    final p30 = SettingsService.iptvLiveBufferProfileForSecs(30);
    expect(p30.cacheSecs, 30);
    expect(p30.demuxerMaxBytes, 150000000);
  });

  test('iptv live buffer secs persist', () async {
    final service = SettingsService();
    expect(await service.getIptvLiveBufferSecs(), 0);
    await service.setIptvLiveBufferSecs(30);
    expect(await service.getIptvLiveBufferSecs(), 30);
    await service.setIptvLiveBufferSecs(99);
    expect(await service.getIptvLiveBufferSecs(), 0);
  });

  test('navbar tab order keeps hidden tabs in place', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.phone);
    SettingsService.registerExtraNavIds(const ['live_matches', 'home']);
    await service.setNavbarConfig(
      const ['iptv'],
      tabOrder: const ['live_matches', 'iptv', 'home'],
    );

    expect((await service.getNavbarTabOrder()).take(3).toList(), [
      'live_matches',
      'iptv',
      'home',
    ]);
    expect(await service.getNavbarConfig(), ['iptv']);
  });

  test('ensureActiveDefaultHubsVisible restores stripped hubs', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.phone);
    await service.setNavbarConfig(const ['iptv']);

    await service.ensureActiveDefaultHubsVisible(
      activeHubIds: const {
        'home',
        'anime',
        'asian_drama',
        'live_matches',
        'mylist',
      },
    );

    expect(await service.getNavbarConfig(), [
      'iptv',
      'home',
      'anime',
      'asian_drama',
      'live_matches',
      'mylist',
    ]);
  });

  test('ensureActiveDefaultHubsVisible no-op when a hub already visible',
      () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.phone);
    await service.setNavbarConfig(const ['iptv', 'home']);

    await service.ensureActiveDefaultHubsVisible(
      activeHubIds: const {'home', 'anime'},
    );

    expect(await service.getNavbarConfig(), ['iptv', 'home']);
  });

  test('ensureNavIdsKnown auto-shows first-seen hub tabs', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.phone);
    expect(await service.getNavbarConfig(), ['iptv']);

    await service.ensureNavIdsKnown(
      allHubIds: const ['hub_alpha', 'hub_beta'],
    );

    expect(await service.getNavbarConfig(), [
      'iptv',
      'hub_alpha',
      'hub_beta',
    ]);

    await service.setNavbarConfig(const ['iptv']);
    await service.ensureNavIdsKnown(
      allHubIds: const ['hub_alpha', 'hub_beta'],
    );
    // Already known — must not force-show again after user hide.
    expect(await service.getNavbarConfig(), ['iptv']);
  });
}
