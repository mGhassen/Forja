import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('hostHttpRequestJson rejects empty url', () {
    final raw = RustLib.instance.hostHttpRequestJson(
      '{"url":"","method":"GET"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
  });

  test('mediaExtraRequestJson rejects unknown action', () {
    final raw = RustLib.instance.mediaExtraRequestJson(
      '{"action":"nope"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], contains('unknown action'));
  });

  test('mediaExtraRequestJson rejects p2a upload without epub', () {
    final raw = RustLib.instance.mediaExtraRequestJson(
      '{"action":"p2a_upload","file_name":"a.epub","voice_id":"af_heart"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
  });
}
