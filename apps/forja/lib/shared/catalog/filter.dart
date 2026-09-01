import 'protocol.dart';

/// Merge shell chrome selections (mood chips, genre / year / sort dropdowns)
/// into the `params` map a hub action receives.
Map<String, dynamic> catalogParamsWithFilters(
  Map<String, dynamic> params, {
  Iterable<Map<String, dynamic>?> filters = const [],
  String? sort,
  String? cursor,
  int? limit,
}) {
  final merged = CatalogFilterAst.andFilters([
    CatalogFilterAst.parse(params['filter']),
    ...filters,
  ]);
  return {
    ...params,
    'filter': ?merged,
    if (sort != null && sort.trim().isNotEmpty) 'sort': sort.trim(),
    if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    if (limit != null && limit > 0) 'limit': limit,
  };
}

/// Chip / dropdown selection → filter leaf. Null when nothing is selected.
Map<String, dynamic>? catalogFilterFromSelection({
  required String field,
  Object? value,
}) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  if (value is Iterable) {
    final values = [
      for (final v in value)
        if (v != null && v.toString().trim().isNotEmpty) v.toString().trim(),
    ];
    if (values.isEmpty) return null;
    return CatalogFilterAst.inList(field, values);
  }
  return CatalogFilterAst.eq(field, value);
}

/// Filter leaf for a pack `filters` action option (Categories menu / chrome).
///
/// - explicit `filter` on the option wins
/// - AniList-style `genre` string → upstream genre name
/// - TMDB-style `movieGenres` / `tvGenres` → `mood` id (pack resolves ids)
/// - KissKH-style `value` chips → defer to [field] + [value] in categoryFilters
Map<String, dynamic>? catalogPackOptionFilter(Map<String, dynamic> option) {
  final direct = CatalogFilterAst.parse(option['filter']);
  if (direct != null) return direct;
  final genre = (option['genre'] ?? '').toString().trim();
  if (genre.isNotEmpty) {
    return CatalogFilterAst.eq('genre', genre);
  }
  final hasMoodGenres =
      option['movieGenres'] is List || option['tvGenres'] is List;
  final id = (option['id'] ?? '').toString().trim();
  if (hasMoodGenres && id.isNotEmpty) {
    return CatalogFilterAst.eq('mood', id);
  }
  return null;
}

/// Filter leaves declared by a layout `mood` widget option.
Map<String, dynamic>? catalogMoodFilter(Map<String, dynamic> option) {
  final direct = CatalogFilterAst.parse(option['filter']);
  if (direct != null) return direct;
  final genre = (option['genre'] ?? '').toString().trim();
  if (genre.isNotEmpty) {
    return CatalogFilterAst.inList('genre', [genre]);
  }
  final id = (option['id'] ?? '').toString().trim();
  if (id.isEmpty) return null;
  // Home moods: pack resolve uses `mood` id (+ movieGenres in the script).
  return CatalogFilterAst.eq('mood', id);
}
