// bestsimilar.com scraper — title autocomplete + similar-movies extraction.
//
// Catalog fetch + HTML parse run in Rust (`catalog-core`). Dart keeps
// in-memory caches and TMDB enrichment fields on [BSItem].

import 'package:flutter/foundation.dart';

import 'package:rust/rust.dart';

class BSAutocompleteHit {
  final int id;
  final String slug;
  final String label;
  final String title;
  final int? year;
  final bool isTv;
  final String url;

  const BSAutocompleteHit({
    required this.id,
    required this.slug,
    required this.label,
    required this.title,
    required this.year,
    required this.isTv,
    required this.url,
  });
}

class BSItem {
  final int id;
  final String slug;
  final String title;
  final int? year;
  final double? rating;
  final String? voteCount;
  final String thumbUrl;
  final int? similarityPercent;
  final String? genre;
  final String? country;
  final String? duration;
  final String? story;
  final List<String> styleTags;
  final List<String> plotTags;
  final List<String> audienceTags;
  final List<String> timeTags;
  final List<String> placeTags;

  String? tmdbPosterUrl;
  String? tmdbBackdropUrl;
  int? tmdbId;
  String? tmdbMediaType;

  BSItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.year,
    required this.rating,
    required this.voteCount,
    required this.thumbUrl,
    required this.similarityPercent,
    required this.genre,
    required this.country,
    required this.duration,
    required this.story,
    required this.styleTags,
    required this.plotTags,
    required this.audienceTags,
    required this.timeTags,
    required this.placeTags,
  });

  String get displayTitle => year != null ? '$title ($year)' : title;
}

class BSDetails {
  final int id;
  final String slug;
  final String title;
  final int? year;
  final double? rating;
  final String? voteCount;
  final String thumbUrl;
  final String? story;
  final String? genre;
  final String? country;
  final String? duration;
  final List<String> styleTags;
  final List<String> plotTags;
  final List<String> audienceTags;
  final List<String> timeTags;
  final List<String> placeTags;
  final String? blurb;
  final List<BSItem> similar;

  const BSDetails({
    required this.id,
    required this.slug,
    required this.title,
    required this.year,
    required this.rating,
    required this.voteCount,
    required this.thumbUrl,
    required this.story,
    required this.genre,
    required this.country,
    required this.duration,
    required this.styleTags,
    required this.plotTags,
    required this.audienceTags,
    required this.timeTags,
    required this.placeTags,
    required this.blurb,
    required this.similar,
  });
}

class BestSimilarScraper {
  static const String baseUrl = 'https://bestsimilar.com';

  static final Map<String, List<BSAutocompleteHit>> _autocompleteCache = {};
  static final Map<int, BSDetails> _detailsCache = {};

  static Future<List<BSAutocompleteHit>> autocomplete(String term) async {
    final q = term.trim();
    if (q.isEmpty) return const [];
    final cached = _autocompleteCache[q.toLowerCase()];
    if (cached != null) return cached;

    try {
      final decoded = await catalogCore({
        'action': 'autocomplete',
        'query': q,
      });
      final out = ((decoded['hits'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_hitFromJson)
          .toList();
      _autocompleteCache[q.toLowerCase()] = out;
      if (_autocompleteCache.length > 80) {
        _autocompleteCache.remove(_autocompleteCache.keys.first);
      }
      return out;
    } catch (e) {
      debugPrint('[BestSimilar] autocomplete failed: $e');
      return const [];
    }
  }

  static Future<BSAutocompleteHit?> findBest({
    required String title,
    int? year,
    bool isTv = false,
  }) async {
    try {
      final decoded = await catalogCore({
        'action': 'find_best',
        'title': title,
        if (year != null) 'year': year,
        'is_tv': isTv,
      });
      final hit = decoded['hit'];
      if (hit is! Map) return null;
      return _hitFromJson(hit.cast<String, dynamic>());
    } catch (e) {
      debugPrint('[BestSimilar] findBest failed: $e');
      return null;
    }
  }

  static Future<BSDetails?> fetchDetails({
    required int id,
    required String slug,
  }) async {
    final cached = _detailsCache[id];
    if (cached != null) return cached;

    try {
      final decoded = await catalogCore({
        'action': 'details',
        'id': id,
        'slug': slug,
      });
      final raw = decoded['details'];
      if (raw is! Map) return null;
      final parsed = _detailsFromJson(raw.cast<String, dynamic>());
      _detailsCache[id] = parsed;
      if (_detailsCache.length > 30) {
        _detailsCache.remove(_detailsCache.keys.first);
      }
      return parsed;
    } catch (e) {
      debugPrint('[BestSimilar] details failed for $slug: $e');
      return null;
    }
  }

  static BSAutocompleteHit _hitFromJson(Map<String, dynamic> j) =>
      BSAutocompleteHit(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: (j['slug'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        year: (j['year'] as num?)?.toInt(),
        isTv: j['is_tv'] == true || j['isTv'] == true,
        url: (j['url'] ?? '') as String,
      );

  static BSItem _itemFromJson(Map<String, dynamic> j) => BSItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: (j['slug'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        year: (j['year'] as num?)?.toInt(),
        rating: (j['rating'] as num?)?.toDouble(),
        voteCount: j['vote_count'] as String? ?? j['voteCount'] as String?,
        thumbUrl: (j['thumb_url'] ?? j['thumbUrl'] ?? '') as String,
        similarityPercent: (j['similarity_percent'] as num?)?.toInt() ??
            (j['similarityPercent'] as num?)?.toInt(),
        genre: j['genre'] as String?,
        country: j['country'] as String?,
        duration: j['duration'] as String?,
        story: j['story'] as String?,
        styleTags: _stringList(j['style_tags'] ?? j['styleTags']),
        plotTags: _stringList(j['plot_tags'] ?? j['plotTags']),
        audienceTags: _stringList(j['audience_tags'] ?? j['audienceTags']),
        timeTags: _stringList(j['time_tags'] ?? j['timeTags']),
        placeTags: _stringList(j['place_tags'] ?? j['placeTags']),
      );

  static BSDetails _detailsFromJson(Map<String, dynamic> j) => BSDetails(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: (j['slug'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        year: (j['year'] as num?)?.toInt(),
        rating: (j['rating'] as num?)?.toDouble(),
        voteCount: j['vote_count'] as String? ?? j['voteCount'] as String?,
        thumbUrl: (j['thumb_url'] ?? j['thumbUrl'] ?? '') as String,
        story: j['story'] as String?,
        genre: j['genre'] as String?,
        country: j['country'] as String?,
        duration: j['duration'] as String?,
        styleTags: _stringList(j['style_tags'] ?? j['styleTags']),
        plotTags: _stringList(j['plot_tags'] ?? j['plotTags']),
        audienceTags: _stringList(j['audience_tags'] ?? j['audienceTags']),
        timeTags: _stringList(j['time_tags'] ?? j['timeTags']),
        placeTags: _stringList(j['place_tags'] ?? j['placeTags']),
        blurb: j['blurb'] as String?,
        similar: ((j['similar'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_itemFromJson)
            .toList(),
      );

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
}
