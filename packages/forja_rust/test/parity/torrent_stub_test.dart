import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
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
}
