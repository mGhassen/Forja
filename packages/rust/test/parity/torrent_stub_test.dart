import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  tearDown(() {
    ForjaRust.instance.torrentEngineStop();
    ForjaRust.instance.torrentStop();
  });

  test('torrent start rejects invalid magnet', () {
    expect(ForjaRust.instance.torrentStart('not-a-magnet'), isFalse);
  });

  test('torrent stop clears running state', () {
    ForjaRust.instance.torrentStop();
    expect(ForjaRust.instance.torrentIsRunning(), isFalse);
  });

  test('torrent status json when idle', () {
    ForjaRust.instance.torrentStop();
    expect(ForjaRust.instance.torrentStatusJson(), 'null');
  });

  test('torrent engine starts on loopback', () {
    final port = ForjaRust.instance.torrentEngineStart(0);
    expect(port, greaterThan(0));
    expect(ForjaRust.instance.torrentEnginePort(), port);
  });

  test('torrent list files json rejects invalid magnet', () {
    ForjaRust.instance.torrentEngineStart(0);
    final json = ForjaRust.instance.torrentListFilesJson('not-a-magnet');
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    expect(parsed['error'], isNotNull);
  });
}
