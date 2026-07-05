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

  /// Parses Xtream `get_series_info` response into normalized episode rows.
  static List<Map<String, dynamic>> parseSeriesEpisodesRows(String json) {
    try {
      final root = jsonDecode(json) as Map<String, dynamic>;
      final episodesObj = root['episodes'] as Map<String, dynamic>?;
      if (episodesObj == null) return const [];

      final out = <Map<String, dynamic>>[];
      episodesObj.forEach((seasonKey, value) {
        final arr = value as List?;
        if (arr == null) return;
        final seasonNum = int.tryParse(seasonKey) ?? 0;
        for (final e in arr) {
          final o = e as Map<String, dynamic>?;
          if (o == null) continue;
          final info = o['info'] as Map<String, dynamic>?;
          final ext = _fieldString(o, 'container_extension');
          out.add({
            'id': _fieldString(o, 'id'),
            'title': _fieldString(o, 'title'),
            'container_ext': ext.isEmpty ? 'mp4' : ext,
            'season': seasonNum,
            'episode': o['episode_num'] is num
                ? (o['episode_num'] as num).toInt()
                : (int.tryParse(_fieldString(o, 'episode_num')) ?? 0),
            'plot': info?['plot']?.toString() ?? '',
            'image': info?['movie_image']?.toString() ?? '',
          });
        }
      });

      out.sort((a, b) {
        final s = (a['season'] as int).compareTo(b['season'] as int);
        return s != 0 ? s : (a['episode'] as int).compareTo(b['episode'] as int);
      });
      return out;
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
