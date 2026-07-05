import 'dart:convert';

/// Optional Rust HTML parser hooks. Set from app bootstrap when [ForjaEngine] loads.
abstract final class ScraperParseBackend {
  static List<Map<String, dynamic>> Function(String html)? parseKnaben;
  static List<Map<String, dynamic>> Function(String html, String source)?
      parseTpb;
  static List<Map<String, dynamic>> Function(String html)? parseUindex;
  static List<Map<String, dynamic>> Function(
    List<Map<String, dynamic>> results,
  )? dedupTorrents;
}

List<Map<String, dynamic>> torrentRowsFromJson(String json) {
  final list = jsonDecode(json) as List;
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

/// Rust uses `source`; Dart scrapers use the same keys.
Map<String, dynamic> normalizeTorrentRow(Map<String, dynamic> row) {
  return {
    'name': row['name'] ?? '',
    'magnet': row['magnet'] ?? '',
    'seeders': row['seeders'] ?? 'Unknown',
    'size': row['size'] ?? 'Unknown',
    'source': row['source'] ?? '',
  };
}
