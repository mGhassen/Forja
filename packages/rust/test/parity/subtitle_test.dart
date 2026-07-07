import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('subtitleRequestJson rejects unknown action', () {
    final raw = RustLib.instance.subtitleRequestJson('{"action":"nope"}');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], contains('unknown action'));
  });

  test('subtitleRequestJson rejects subtitlecat without title', () {
    final raw = RustLib.instance.subtitleRequestJson(
      '{"action":"subtitlecat_fetch"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
  });

  test('subtitleRequestJson rejects mysubs without title', () {
    final raw = RustLib.instance.subtitleRequestJson(
      '{"action":"mysubs_fetch"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
  });

  test('subtitleRequestJson rejects kisskh without url', () {
    final raw = RustLib.instance.subtitleRequestJson(
      '{"action":"kisskh_fetch_decrypt"}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
  });
}
