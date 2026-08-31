import 'dart:convert';

import 'isolate_runner.dart';

/// Lyrics + paper2audio — `media-extra` Rust crate.
Future<Map<String, dynamic>> mediaExtraRequest(
  Map<String, dynamic> payload,
) async {
  final raw = await runMediaExtraRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}
