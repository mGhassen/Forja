import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
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
    await openFreshStore();
  });

  tearDown(() {
    PlatformPlayback.clearOverride();
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
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
  });
}
