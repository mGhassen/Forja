import 'dart:convert';
import 'dart:io';

import 'helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

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
    await Engine.init(storagePath: '${Directory.systemTemp.path}/forja_seed_init.json');
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
    expect(await service.getSubSize(), 52);
    expect(await service.getSubBottomPadding(), 48);
    expect(await service.getTorrentRamCacheMb(), 128);
    expect(await service.isPlaySourceWebstreamingEnabled(), isTrue);
    expect(await service.isPlaySourceTorrentEnabled(), isFalse);
    expect(await service.isPlaySourceStremioEnabled(), isFalse);
  });

  test('fresh phone install seeds phone nav defaults', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.phone);

    final nav = await service.getNavbarConfig();
    expect(nav, PlatformDefaults.phoneNavIds);
    expect(await service.getSubSize(), 24);
    expect(await service.getTorrentRamCacheMb(), 200);
  });

  test('fresh desktop install seeds desktop subtitle default', () async {
    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.desktop);

    expect(await service.getSubSize(), 44);
    expect(await service.getNavbarConfig(), PlatformDefaults.phoneNavIds);
  });

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
    await kvSetStringList('navbar_known_ids', List.from(SettingsService.allNavIds));
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');

    final service = SettingsService();
    await service.ensurePlatformDefaultsSeeded(PlatformProfile.androidTv);

    final nav = await service.getNavbarConfig();
    expect(nav, contains('home'));
    expect(nav, contains('iptv'));
    expect(nav.indexOf('home'), lessThan(nav.indexOf('iptv')));
  });

  test('Android TV search-first nav migrates back to home-first', () async {
    await kvSetStringList('navbar_config', const [
      'search',
      'home',
      'anime',
      'asian_drama',
      'iptv',
      'live_matches',
      'mylist',
    ]);
    await kvSetStringList('navbar_known_ids', List.from(SettingsService.allNavIds));
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');
    await kvSetString('navbar_shell_084', '1');
    await kvSetString('navbar_shell_085', '1');

    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    final service = SettingsService();
    final nav = await service.getNavbarConfig();

    expect(nav.take(2), ['home', 'search']);
  });

  test('desktop search-first nav migrates back to home-first', () async {
    await kvSetStringList('navbar_config', const ['search', 'home', 'mylist']);
    await kvSetStringList('navbar_known_ids', List.from(SettingsService.allNavIds));
    await kvSetString('navbar_shell_080', '1');
    await kvSetString('navbar_shell_081', '1');
    await kvSetString('navbar_shell_084', '1');
    await kvSetString('navbar_shell_085', '1');
    await kvSetString('navbar_shell_086', '1');

    SettingsService.configurePlatformProfile(PlatformProfile.desktop);
    final service = SettingsService();
    final nav = await service.getNavbarConfig();

    expect(nav.take(2), ['home', 'search']);
  });
}
