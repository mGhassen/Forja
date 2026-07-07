import 'dart:convert';

import 'isolate_runner.dart';

Future<Map<String, dynamic>> debridRequest(Map<String, dynamic> payload) async {
  final raw = await runDebridRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}

List<DebridFile> parseDebridFiles(Map<String, dynamic> decoded) {
  final files = decoded['files'] as List<dynamic>? ?? [];
  return files
      .map(
        (e) => DebridFile(
          filename: e['filename'] as String? ?? '',
          filesize: (e['filesize'] as num?)?.toInt() ?? 0,
          downloadUrl: e['download_url'] as String? ?? '',
        ),
      )
      .toList();
}

class DebridFile {
  final String filename;
  final int filesize;
  final String downloadUrl;

  DebridFile({
    required this.filename,
    required this.filesize,
    required this.downloadUrl,
  });
}
