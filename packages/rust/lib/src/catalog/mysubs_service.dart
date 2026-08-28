import '../subtitle_http.dart';

/// my-subs.co scraper via `anime/mysubs`.
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
        'year': ?year,
        'season': ?season,
        'episode': ?episode,
      });
    } catch (_) {
      return [];
    }
  }
}
