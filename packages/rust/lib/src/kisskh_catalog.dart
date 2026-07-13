import 'dart:convert';

import 'isolate_runner.dart';

Future<Map<String, dynamic>> kisskhCatalog(Map<String, dynamic> payload) async {
  final raw = await runKisskhCatalogJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}
