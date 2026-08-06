import 'package:rust/rust.dart';

/// Last typed search queries per scope (Search tab, Anime hub, Asian Drama hub).
class SearchRecentQueries {
  SearchRecentQueries._();

  static const int maxEntries = 5;

  /// Max suggestion titles under recent searches (left column).
  static const int maxRecommendations = 16;

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
    }
    final cleaned = _collapseTypingPartials(out);
    if (cleaned.length > maxEntries) {
      cleaned.removeRange(maxEntries, cleaned.length);
    }
    final changed = cleaned.length != out.length ||
        !_sameSequence(cleaned, out.take(maxEntries).toList());
    if (changed) {
      await kvSetStringList(_key(scope), cleaned);
    }
    return cleaned;
  }

  /// Drop shorter prefixes left by TV IME debounce (M, Mi, Mic → Michael).
  static List<String> _collapseTypingPartials(List<String> entries) {
    return [
      for (final q in entries)
        if (!_isStrictPrefixOfAny(q, entries)) q,
    ];
  }

  static bool _isStrictPrefixOfAny(String candidate, List<String> entries) {
    final lower = candidate.toLowerCase();
    for (final other in entries) {
      final o = other.toLowerCase();
      if (o != lower && o.startsWith(lower) && o.length > lower.length) {
        return true;
      }
    }
    return false;
  }

  static bool _sameSequence(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) return false;
    }
    return true;
  }

  /// Push [query] to the front (case-insensitive dedupe). Returns the new list.
  static Future<List<String>> record(String scope, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load(scope);

    final trimmedLower = trimmed.toLowerCase();
    final current = await load(scope);
    final next = <String>[
      trimmed,
      // Drop case-insensitive dupes and shorter prefixes (TV typing partials).
      ...current.where((q) {
        final lower = q.toLowerCase();
        if (lower == trimmedLower) return false;
        if (trimmedLower.startsWith(lower) &&
            lower.length < trimmedLower.length) {
          return false;
        }
        return true;
      }),
    ];
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    await kvSetStringList(_key(scope), next);
    return next;
  }

  /// Unique titles from [candidates], skipping [exclude], capped at [max].
  static List<String> pickRecommendations(
    Iterable<String> candidates, {
    Iterable<String> exclude = const [],
    int max = maxRecommendations,
  }) {
    final seen = <String>{
      for (final e in exclude)
        if (e.trim().isNotEmpty) e.trim().toLowerCase(),
    };
    final out = <String>[];
    for (final raw in candidates) {
      final title = raw.trim();
      if (title.isEmpty) continue;
      if (!seen.add(title.toLowerCase())) continue;
      out.add(title);
      if (out.length >= max) break;
    }
    return out;
  }
}
