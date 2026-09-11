part of 'search_screen.dart';

class _SearchSection {
  final String key;
  final String title;
  final String? icon; // network icon URL (for addon sections)
  final bool isTmdb;
  List<dynamic> results; // Movie for TMDB, Map<String,dynamic> for addons

  _SearchSection({
    required this.key,
    required this.title,
    this.icon,
    this.isTmdb = false,
    List<dynamic>? results,
  }) : results = results ?? [];
}

class _FlatSearchResult {
  const _FlatSearchResult({
    required this.key,
    required this.title,
    required this.overview,
    required this.posterUrl,
    this.backdropUrl,
    this.year,
    this.rating,
    this.kind,
    required this.isTmdb,
    required this.raw,
  });

  final String key;
  final String title;
  final String overview;
  final String posterUrl;
  final String? backdropUrl;
  final String? year;
  final double? rating;
  final String? kind;
  final bool isTmdb;
  final dynamic raw;

  String? get metaLine {
    final parts = <String>[
      if (year != null && year!.isNotEmpty) year!,
      if (kind != null && kind!.isNotEmpty) kind!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }
}

class _SearchHelperEntry {
  const _SearchHelperEntry(
    this.title, {
    required this.isRecent,
  });

  final String title;
  final bool isRecent;
}
