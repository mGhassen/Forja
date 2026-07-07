import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_test_init.dart';
import 'helpers/torrent_e2e.dart';

/// Mobile magnet E2E — run on Android/iOS device or emulator:
///   ./scripts/run_mobile_magnet_e2e.sh
/// Optional full magnet flow (slow, needs network):
///   TORRENT_E2E=1 ./scripts/run_mobile_magnet_e2e.sh
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (!isMobilePlatform) {
    test(
      'mobile magnet E2E skipped on ${Platform.operatingSystem}',
      () {},
      skip: 'Run on Android/iOS: ./scripts/run_mobile_magnet_e2e.sh',
    );
    return;
  }

  setUpAll(() async {
    await initEngineForTests();
  });

  setUp(() {
    if (RustLib.isInitialized) {
      RustLib.instance.torrentEngineStop();
      RustLib.instance.torrentStop();
    }
  });

  tearDown(() {
    if (RustLib.isInitialized) {
      RustLib.instance.torrentEngineStop();
      RustLib.instance.torrentStop();
    }
  });

  test('mobile engine loads libffi with torrent features', () {
    expect(
      Engine.isReady,
      isTrue,
      reason: 'Run ./scripts/build_rust_mobile.sh before mobile E2E',
    );
    expect(RustLib.instance.version, isNotEmpty);
  });

  test('mobile playback profile allows local torrent engine', () {
    expect(PlatformPlayback.capabilities.localTorrentEngine, isTrue);
    expect(PlatformPlayback.capabilities.canPlayInfoHashLocally, isTrue);
  });

  test('torrent engine starts on loopback (mobile FFI)', () {
    final port = RustLib.instance.torrentEngineStart(0);
    expect(port, greaterThan(0));
    expect(RustLib.instance.torrentEnginePort(), port);
  });

  test('invalid magnet rejected (mobile FFI)', () {
    RustLib.instance.torrentEngineStart(0);
    expect(RustLib.instance.torrentStart('not-a-magnet'), isFalse);
  });

  test('TorrentStreamService lifecycle on mobile', () async {
    final svc = TorrentStreamService();
    expect(await svc.start(), isTrue);
    expect(svc.state, EngineState.ready);
    await svc.cleanup();
  });

  test('magnet stream E2E (optional — TORRENT_E2E=1)', () async {
    final magnet = torrentE2eMagnet();
    if (magnet == null) return;
    await runMagnetStreamE2e(magnet);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
