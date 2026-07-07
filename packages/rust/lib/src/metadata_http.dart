import 'dart:convert';

import 'isolate_runner.dart';

Future<Map<String, dynamic>> metadataRequest(Map<String, dynamic> payload) async {
  final raw = await runMetadataRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}
