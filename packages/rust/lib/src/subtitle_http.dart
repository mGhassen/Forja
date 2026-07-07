import 'dart:convert';

import 'isolate_runner.dart';

Future<Map<String, dynamic>> subtitleRequest(Map<String, dynamic> payload) async {
  final raw = await runSubtitleRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}

Future<List<Map<String, dynamic>>> subtitleEntries(
  Map<String, dynamic> payload,
) async {
  final decoded = await subtitleRequest(payload);
  final entries = decoded['entries'];
  if (entries is! List) return [];
  return entries
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}
