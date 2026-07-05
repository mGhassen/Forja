/// Port of webstreamr/src/source/StreamKiste.ts
library;

import 'package:html/parser.dart' as html_parser;

import '../types.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class StreamKisteSource extends Source {
  StreamKisteSource(super.fetcher);

  @override
  String get id => 'streamkiste';
  @override
  String get label => 'StreamKiste';
  @override
  List<String> get contentTypes => const ['series'];
  @override
  List<CountryCode> get countryCodes => const [CountryCode.de];
  @override
  String get baseUrl => 'https://streamkiste.taxi';

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final tmdbId = await getTmdbId(ctx, fetcher, id);
    final seriesPageUrl = await _fetchSeriesPageUrl(ctx, tmdbId);
    if (seriesPageUrl == null) return const [];

    final html = await fetcher.text(ctx, seriesPageUrl);
    return requireRustParseSourceHtml(
      this.id,
      html,
      referer: seriesPageUrl.toString(),
      season: tmdbId.season,
      episode: tmdbId.episode,
    );
  }

  Future<Uri?> _fetchSeriesPageUrl(Context ctx, TmdbId tmdbId) async {
    final url = Uri.parse(
        '$baseUrl/?story=${tmdbId.id}&do=search&subaction=search');
    final html = await fetcher.text(ctx, url);
    final doc = html_parser.parse(html);
    final href = doc.querySelector('.res_item a[href]')?.attributes['href'];
    return href == null ? null : Uri.parse(href);
  }
}
