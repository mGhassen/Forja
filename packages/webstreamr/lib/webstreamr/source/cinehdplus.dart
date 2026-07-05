/// Port of webstreamr/src/source/CineHDPlus.ts
library;

import 'package:html/parser.dart' as html_parser;

import '../types.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class CineHDPlusSource extends Source {
  CineHDPlusSource(super.fetcher);

  @override
  String get id => 'cinehdplus';
  @override
  String get label => 'CineHDPlus';
  @override
  List<String> get contentTypes => const ['series'];
  @override
  List<CountryCode> get countryCodes =>
      const [CountryCode.es, CountryCode.mx];
  @override
  String get baseUrl => 'https://cinehdplus.gratis';

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final tmdbId = await getTmdbId(ctx, fetcher, id);
    final pageUrl = await _fetchSeriesPageUrl(ctx, tmdbId);
    if (pageUrl == null) return const [];

    final html = await fetcher.text(ctx, pageUrl);
    return requireRustParseSourceHtml(
      this.id,
      html,
      referer: pageUrl.toString(),
      season: tmdbId.season,
      episode: tmdbId.episode,
    );
  }

  Future<Uri?> _fetchSeriesPageUrl(Context ctx, TmdbId tmdbId) async {
    final url = Uri.parse(
        '$baseUrl/series/?story=${tmdbId.id}&do=search&subaction=search');
    final html = await fetcher.text(ctx, url);
    final doc = html_parser.parse(html);
    final href = doc.querySelector('.card__title a[href]')?.attributes['href'];
    return href == null ? null : Uri.parse(href);
  }
}
