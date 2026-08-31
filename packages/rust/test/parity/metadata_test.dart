import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('metadataRequestJson rejects unknown action', () {
    final raw = RustLib.instance.metadataRequestJson('{"action":"nope"}');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], contains('unknown action'));
  });

  test('metadataRequestJson rejects mdblist remove without id', () {
    final raw = RustLib.instance.metadataRequestJson(
      '{"action":"mdblist_remove_from_list","api_key":"k","list_id":1}',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
  });
}
