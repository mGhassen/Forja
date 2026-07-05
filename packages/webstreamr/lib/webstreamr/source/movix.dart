/// Port of webstreamr/src/source/Movix.ts
library;

import 'dart:convert';

import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class MovixSource extends Source {
  MovixSource(super.fetcher);

  @override
  String get id => 'movix';
  @override
  String get label => 'Movix';
  @override
  List<String> get contentTypes => const ['movie', 'series'];
  @override
  List<CountryCode> get countryCodes => const [CountryCode.fr];
  @override
  String get baseUrl => 'https://api.movix.site';

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final tmdbId = await getTmdbId(ctx, fetcher, id);
    final ny = await getTmdbNameAndYear(ctx, fetcher, tmdbId);
    final year = ny[1] as int;

    final apiUrl = tmdbId.season != null
        ? Uri.parse(
            '$baseUrl/api/tmdb/tv/${tmdbId.id}?season=${tmdbId.season}&episode=${tmdbId.episode}')
        : Uri.parse('$baseUrl/api/tmdb/movie/${tmdbId.id}');

    Map<String, dynamic> json;
    try {
      json = await fetcher.json(
          ctx,
          apiUrl,
          FetcherRequestConfig(
              headers: {'Accept': 'application/json'})) as Map<String, dynamic>;
    } on FormatException {
      return const [];
    }

    return requireRustParseSourceHtml(
      this.id,
      jsonEncode(json),
      referer: iframeSrcFromJson(json, tmdbId),
      isSeries: tmdbId.season != null,
      season: tmdbId.season,
      episode: tmdbId.episode,
      year: year,
    );
  }

  String iframeSrcFromJson(Map<String, dynamic> json, TmdbId tmdbId) {
    final data = (tmdbId.season != null
            ? json['current_episode']
            : json) as Map<String, dynamic>?;
    return data?['iframe_src']?.toString() ?? baseUrl;
  }
}
