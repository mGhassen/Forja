import '../subtitle_http.dart';

/// my-subs.co scraper via `anime-core/mysubs`.
class MysubsService {
  MysubsService._();
  static final MysubsService instance = MysubsService._();

  Future<List<Map<String, dynamic>>> fetchAll({
    required String title,
    int? year,
    int? season,
    int? episode,
  }) async {
    try {
      return await subtitleEntries({
        'action': 'mysubs_fetch',
        'title': title,
        if (year != null) 'year': year,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
      });
    } catch (_) {
      return [];
    }
  }
}
