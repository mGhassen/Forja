import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_engine.dart';

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
    await initRustForAppTests();
    await Engine.init(
      storagePath: '${Directory.systemTemp.path}/forja_settings_vis_init.json',
    );
    tmp = await Directory.systemTemp.createTemp('forja_settings_vis_');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  setUp(() async {
    PlatformPlayback.clearOverride();
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    PlaySourceEffective.debugForceLanDesktopOnline = null;
    await openFreshStore();
  });

  tearDown(() async {
    PlatformPlayback.clearOverride();
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    PlaySourceEffective.debugForceLanDesktopOnline = null;
    await LanPrefs.instance.clearServer();
  });

  test('Android TV hides Sources, WebStreamr, Lists, Data, Debrid, torrent',
      () async {
    PlatformPlayback.override = PlaybackProfile.androidTv;
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);

    final service = SettingsService();
    // Seed shell migration markers so getNavbarConfig won't rewrite our nav.
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
    await service.setNavbarConfig([
      'home',
      'anime',
      'iptv',
      'mylist',
    ]);
    // Synced phone prefs must not reopen TV-hidden tiles.
    await service.setPlaySourceTorrentEnabled(true);
    await service.setPlaySourceStremioEnabled(true);
    await service.setPlaySourceNuvioEnabled(true);
    await service.setPlaySourceWebstreamingEnabled(true);

    final v = await SettingsVisibility.resolve(service);
    expect(v.playSourceTorrent, isFalse);
    expect(v.playSourceStremio, isFalse);
    expect(v.playSourceNuvio, isFalse);
    expect(v.playSourceWebstreaming, isTrue);
    expect(v.showProviderScoring, isFalse);
    expect(v.showSourcesCategory, isFalse);
    expect(v.showWebstreamr, isFalse);
    expect(v.showLists, isFalse);
    expect(v.showDataCategory, isFalse);
    expect(v.showDebrid, isFalse);
    expect(v.showTorrentEngine, isFalse);
    expect(v.showStremioAddons, isFalse);
    expect(v.showNuvio, isFalse);
    expect(v.showAccounts, isTrue);
    expect(v.showTrakt, isFalse);

    final ids = settingsCategories(v).map((c) => c.id).toSet();
    expect(ids.contains(SettingsCategoryId.sources), isFalse);
    expect(ids.contains(SettingsCategoryId.webstreamr), isFalse);
    expect(ids.contains(SettingsCategoryId.lists), isFalse);
    expect(ids.contains(SettingsCategoryId.data), isFalse);
    expect(ids.contains(SettingsCategoryId.debrid), isFalse);
    expect(ids.contains(SettingsCategoryId.playback), isTrue);
    expect(ids.contains(SettingsCategoryId.accounts), isTrue);
    expect(ids.contains(SettingsCategoryId.navigation), isTrue);
    expect(ids.contains(SettingsCategoryId.about), isTrue);
    expect(v.showPlaySourceTorrentToggle, isFalse);
    expect(v.showPlaySourceStremioToggle, isFalse);
    expect(v.showPlaySourceNuvioToggle, isFalse);
  });

  test('Android TV paired + online unlocks Playback toggles; honors stored',
      () async {
    PlatformPlayback.override = PlaybackProfile.androidTv;
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    PlaySourceEffective.debugForceLanDesktopOnline = true;

    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
    await service.setNavbarConfig([
      'home',
      'anime',
      'iptv',
      'mylist',
    ]);
    await LanPrefs.instance.setServer(host: '192.168.1.10', port: 8787);
    await LanPrefs.instance.setToken('test-token');
    await service.setPlaySourceTorrentEnabled(true);
    await service.setPlaySourceStremioEnabled(false);
    await service.setPlaySourceNuvioEnabled(true);

    final v = await SettingsVisibility.resolve(service);
    expect(v.showPlaySourceTorrentToggle, isTrue);
    expect(v.showPlaySourceStremioToggle, isTrue);
    expect(v.showPlaySourceNuvioToggle, isTrue);
    expect(v.lanPlaySourcesEditable, isTrue);
    expect(v.playSourceTorrent, isTrue);
    expect(v.playSourceStremio, isFalse);
    expect(v.playSourceNuvio, isTrue);
    expect(v.showSourcesCategory, isFalse);
    expect(v.showDebrid, isFalse);

    expect(await PlaySourceEffective.torrent(service), isTrue);
    expect(await PlaySourceEffective.stremio(service), isFalse);
    expect(await PlaySourceEffective.nuvio(service), isTrue);
  });

  test('Android TV paired + offline deactivates play sources; keeps stored',
      () async {
    PlatformPlayback.override = PlaybackProfile.androidTv;
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    PlaySourceEffective.debugForceLanDesktopOnline = false;

    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);
    await service.setNavbarConfig([
      'home',
      'anime',
      'iptv',
      'mylist',
    ]);
    await LanPrefs.instance.setServer(host: '192.168.1.10', port: 8787);
    await LanPrefs.instance.setToken('test-token');
    await service.setPlaySourceTorrentEnabled(true);
    await service.setPlaySourceStremioEnabled(true);
    await service.setPlaySourceNuvioEnabled(true);

    final v = await SettingsVisibility.resolve(service);
    expect(v.showPlaySourceTorrentToggle, isTrue);
    expect(v.lanPlaySourcesEditable, isFalse);
    expect(v.playSourceTorrent, isFalse);
    expect(v.playSourceStremio, isFalse);
    expect(v.playSourceNuvio, isFalse);

    expect(await service.isPlaySourceTorrentStored(), isTrue);
    expect(await service.isPlaySourceStremioStored(), isTrue);
    expect(await service.isPlaySourceNuvioStored(), isTrue);

    PlaySourceEffective.debugForceLanDesktopOnline = true;
    expect(await PlaySourceEffective.torrent(service), isTrue);
    expect(await PlaySourceEffective.stremio(service), isTrue);
    expect(await PlaySourceEffective.nuvio(service), isTrue);
  });
}
