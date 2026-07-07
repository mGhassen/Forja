import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  tearDown(() {
    RustLib.instance.torrentEngineStop();
    RustLib.instance.torrentStop();
  });

  test('torrent start rejects invalid magnet', () {
    expect(RustLib.instance.torrentStart('not-a-magnet'), isFalse);
  });

  test('torrent stop clears running state', () {
    RustLib.instance.torrentStop();
    expect(RustLib.instance.torrentIsRunning(), isFalse);
  });

  test('torrent status json when idle', () {
    RustLib.instance.torrentStop();
    expect(RustLib.instance.torrentStatusJson(), 'null');
  });

  test('torrent engine starts on loopback', () {
    RustLib.instance.torrentSetPeerLimit(50);
    final port = RustLib.instance.torrentEngineStart(0);
    expect(port, greaterThan(0));
    expect(RustLib.instance.torrentEnginePort(), port);
  });

  test('torrent list files json rejects invalid magnet', () {
    RustLib.instance.torrentEngineStart(0);
    final json = RustLib.instance.torrentListFilesJson('not-a-magnet');
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed['error'], isNotNull);
  });
}
