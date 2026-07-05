/// Port of webstreamr/src/source/VerHdLink.ts
library;

import '../types.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class VerHdLinkSource extends Source {
  VerHdLinkSource(super.fetcher);

  @override
  String get id => 'verhdlink';
  @override
  String get label => 'VerHdLink';
  @override
  List<String> get contentTypes => const ['movie'];
  @override
  List<CountryCode> get countryCodes =>
      const [CountryCode.es, CountryCode.mx];
  @override
  String get baseUrl => 'https://verhdlink.cam';

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final imdbId = await getImdbId(ctx, fetcher, id);
    final pageUrl = Uri.parse('$baseUrl/movie/${imdbId.id}');
    final html = await fetcher.text(ctx, pageUrl);
    return requireRustParseSourceHtml(this.id, html, referer: baseUrl);
  }
}
