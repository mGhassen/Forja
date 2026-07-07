import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('tmdbGetJson rejects empty path', () {
    final raw = RustLib.instance.tmdbGetJson('');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });

  test('tmdbGetJson fetches trending', () async {
    final raw = RustLib.instance.tmdbGetJson('trending/movie/day');
    final decoded = jsonDecode(raw);
    expect(decoded, isA<Map<String, dynamic>>());
    expect((decoded as Map)['results'], isNotNull);
  });
}
