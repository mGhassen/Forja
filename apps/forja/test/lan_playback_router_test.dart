import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/lan/lan_playback_router.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
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
      storagePath: '${Directory.systemTemp.path}/forja_lan_route_init.json',
    );
    tmp = await Directory.systemTemp.createTemp('forja_lan_route_');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  setUp(() async {
    PlatformPlayback.clearOverride();
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    await openFreshStore();
  });

  tearDown(() async {
    PlatformPlayback.clearOverride();
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    await LanPrefs.instance.clearServer();
  });

  test('ATV unpaired torrent route is unavailable; HTTP is playDirect', () async {
    PlatformPlayback.override = PlaybackProfile.androidTv;
    expect(
      await LanPlaybackRouter.routeTorrent(PlaybackProfile.androidTv),
      LanRouteDecision.unavailable,
    );
    expect(
      await LanPlaybackRouter.routeDirectUrl(),
      LanRouteDecision.playDirect,
    );
  });

  test('desktop torrent route stays localEngine', () async {
    expect(
      await LanPlaybackRouter.routeTorrent(PlaybackProfile.desktop),
      LanRouteDecision.localEngine,
    );
    expect(
      await LanPlaybackRouter.routeDirectUrl(),
      LanRouteDecision.playDirect,
    );
  });
}
