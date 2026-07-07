import '../subtitle_http.dart';

/// SubtitleCat search/detail via `anime-core/subtitlecat`.
/// On-demand translation URLs point at the local proxy (`/subtitlecat-translate`).
class SubtitleCatService {
  SubtitleCatService._();
  static final SubtitleCatService instance = SubtitleCatService._();

  static String buildQuery({
    required String title,
    int? year,
    int? season,
    int? episode,
  }) {
    if (season != null && episode != null) {
      final clean = title.split(RegExp(r'\s+')).join(' ').trim();
      return '$clean S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
    }
    final clean = title.split(RegExp(r'\s+')).join(' ').trim();
    if (year != null && year > 0) return '$clean $year';
    return clean;
  }

  Future<List<Map<String, dynamic>>> fetchAll({
    required String title,
    int? year,
    int? season,
    int? episode,
    String? translateBaseUrl,
    int maxResults = 8,
  }) async {
    try {
      return await subtitleEntries({
        'action': 'subtitlecat_fetch',
        'title': title,
        if (year != null) 'year': year,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (translateBaseUrl != null) 'translate_base_url': translateBaseUrl,
        'max_results': maxResults,
      });
    } catch (_) {
      return [];
    }
  }
}
