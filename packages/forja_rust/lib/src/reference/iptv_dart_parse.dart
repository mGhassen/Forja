import 'dart:convert';

/// Dart reference Xtream JSON/text helpers — Rust-off fallback and parity tests.
abstract final class IptvDartParse {
  static String decodeXtreamText(String s) {
    if (s.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(s), allowMalformed: true).trim();
    } catch (_) {
      return s;
    }
  }

  static List<Map<String, dynamic>> parseCategoriesRows(String json) {
    try {
      final arr = jsonDecode(json) as List;
      return arr.map((e) {
        final o = e as Map<String, dynamic>;
        return {
          'id': '${o['category_id'] ?? ''}',
          'name': '${o['category_name'] ?? ''}',
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> parseStreamsRows(String json, String section) {
    try {
      final arr = jsonDecode(json) as List;
      return arr
          .map((e) => _parseStreamRow(e as Map<String, dynamic>, section))
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic>? _parseStreamRow(
    Map<String, dynamic> o,
    String section,
  ) {
    final containerExt = switch (section) {
      'live' => 'ts',
      'vod' => () {
          final ext = _fieldString(o, 'container_extension');
          return ext.isEmpty ? 'mp4' : ext;
        }(),
      _ => '',
    };

    final streamId = switch (section) {
      'series' => () {
          final seriesId = _fieldString(o, 'series_id');
          return seriesId.isEmpty ? _fieldString(o, 'id') : seriesId;
        }(),
      _ => () {
          final id = _fieldString(o, 'stream_id');
          return id.isEmpty ? _fieldString(o, 'id') : id;
        }(),
    };

    final name = () {
      final n = _fieldString(o, 'name');
      return n.isEmpty ? _fieldString(o, 'title') : n;
    }();

    final icon = () {
      final i = _fieldString(o, 'stream_icon');
      return i.isEmpty ? _fieldString(o, 'cover') : i;
    }();

    return {
      'stream_id': streamId,
      'name': name,
      'icon': icon,
      'category_id': _fieldString(o, 'category_id'),
      'container_ext': containerExt,
      'epg_channel_id': _fieldString(o, 'epg_channel_id'),
      'kind': section,
    };
  }

  static String _fieldString(Map<String, dynamic> o, String key) {
    final v = o[key];
    if (v == null) return '';
    return '$v';
  }
}
