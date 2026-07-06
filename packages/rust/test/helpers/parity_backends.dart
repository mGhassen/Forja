import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import 'rust_engine.dart';

/// Load native library for parity tests that call domain APIs alongside FFI.
Future<void> initRustAndWireRustBackends() async {
  await initRustForTests();
}

List<Map<String, dynamic>> m3uRowsFromRust(String content) {
  final json = RustLib.instance.parseM3uJson(content);
  final decoded = jsonDecode(json);
  if (decoded is Map && decoded['error'] != null) {
    throw FormatException(decoded['error'] as String);
  }
  return (decoded as List).cast<Map<String, dynamic>>();
}
