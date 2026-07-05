import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('torrent start accepts valid magnet', () {
    const magnet =
        'magnet:?xt=urn:btih:abc123&dn=Test';
    expect(ForjaRust.instance.torrentStart(magnet), isTrue);
  });

  test('torrent stop clears running state', () {
    ForjaRust.instance.torrentStop();
    expect(ForjaRust.instance.torrentIsRunning(), isFalse);
  });
}
