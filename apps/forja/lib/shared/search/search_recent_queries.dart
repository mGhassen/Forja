import 'package:rust/rust.dart';

/// Last typed search queries per scope (Search tab, Anime hub, Asian Drama hub).
class SearchRecentQueries {
  SearchRecentQueries._();

  static const int maxEntries = 5;

  static const String scopeSearch = 'search';
  static const String scopeAnime = 'anime';
  static const String scopeAsianDrama = 'asian_drama';

  static String _key(String scope) => 'search_recent_queries_$scope';

  static Future<List<String>> load(String scope) async {
    final raw = await kvGetStringList(_key(scope), fallback: const []);
    final out = <String>[];
    final seen = <String>{};
    for (final q in raw) {
      final trimmed = q.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(trimmed);
      if (out.length >= maxEntries) break;
    }
    return out;
  }

  /// Push [query] to the front (case-insensitive dedupe). Returns the new list.
  static Future<List<String>> record(String scope, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load(scope);

    final current = await load(scope);
    final next = <String>[
      trimmed,
      ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ];
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    await kvSetStringList(_key(scope), next);
    return next;
  }
}
