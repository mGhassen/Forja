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

  test('Android TV hides Sources, Debrid, and torrent play sources', () async {
    PlatformPlayback.override = PlaybackProfile.androidTv;
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);

    final service = SettingsService();
    await service.setNavbarConfig([
      'home',
      'search',
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
    expect(v.showSourcesCategory, isFalse);
    expect(v.showDebrid, isFalse);
    expect(v.showTorrentEngine, isFalse);
    expect(v.showStremioAddons, isFalse);
    expect(v.showNuvio, isFalse);
    expect(v.showWebstreamr, isTrue);

    final ids = settingsCategories(v).map((c) => c.id).toSet();
    expect(ids.contains(SettingsCategoryId.sources), isFalse);
    expect(ids.contains(SettingsCategoryId.debrid), isFalse);
    expect(ids.contains(SettingsCategoryId.webstreamr), isTrue);
  });
}
