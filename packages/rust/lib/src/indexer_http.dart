import 'dart:convert';

import 'isolate_runner.dart';

Future<Map<String, dynamic>> indexerRequest(Map<String, dynamic> payload) async {
  final raw = await runIndexerRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}
