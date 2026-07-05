/// Port of webstreamr/src/source/Frembed.ts
library;

import 'dart:convert';

import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class FrembedSource extends Source {
  FrembedSource(super.fetcher);

  @override
  String get id => 'frembed';
  @override
  String get label => 'Frembed';
  @override
  List<String> get contentTypes => const ['movie', 'series'];
  @override
  List<CountryCode> get countryCodes => const [CountryCode.fr];
  @override
  String get baseUrl => 'https://frembed.work';

  Uri? _resolvedBase;
  DateTime? _resolvedAt;
  Future<Uri> _getBaseUrl(Context ctx) async {
    final now = DateTime.now();
    if (_resolvedBase != null &&
        _resolvedAt != null &&
        now.difference(_resolvedAt!) < const Duration(hours: 1)) {
      return _resolvedBase!;
    }
    _resolvedBase = await fetcher.getFinalRedirectUrl(ctx, Uri.parse(baseUrl));
    _resolvedAt = now;
    return _resolvedBase!;
  }

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final tmdbId = await getTmdbId(ctx, fetcher, id);
    final ny = await getTmdbNameAndYear(ctx, fetcher, tmdbId);
    final year = ny[1] as int;

    final base = await _getBaseUrl(ctx);
    final origin = '${base.scheme}://${base.host}';

    final apiUrl = tmdbId.season != null
        ? base.resolve(
            '/api/series?id=${tmdbId.id}&sa=${tmdbId.season}&epi=${tmdbId.episode}&idType=tmdb')
        : base.resolve('/api/films?id=${tmdbId.id}&idType=tmdb');

    final json = await fetcher.json(
            ctx, apiUrl, FetcherRequestConfig(headers: {'Referer': origin}))
        as Map<String, dynamic>;

    final rust = requireRustParseSourceHtml(
      this.id,
      jsonEncode(json),
      referer: origin,
      isSeries: tmdbId.season != null,
      season: tmdbId.season,
      episode: tmdbId.episode,
      year: year,
    );
    final out = <SourceResult>[];
    for (final r in rust) {
      try {
        final resolved = await fetcher.getFinalRedirectUrl(
          ctx,
          r.url,
          FetcherRequestConfig(headers: {'Referer': '$origin/'}),
        );
        out.add(SourceResult(url: resolved, meta: r.meta));
      } catch (_) {
        // skip invalid
      }
    }
    return out;
  }
}
