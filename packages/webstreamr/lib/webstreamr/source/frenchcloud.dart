/// Port of webstreamr/src/source/FrenchCloud.ts
library;

import '../types.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class FrenchCloudSource extends Source {
  FrenchCloudSource(super.fetcher);

  @override
  String get id => 'frenchcloud';
  @override
  String get label => 'FrenchCloud';
  @override
  List<String> get contentTypes => const ['movie'];
  @override
  List<CountryCode> get countryCodes => const [CountryCode.fr];
  @override
  String get baseUrl => 'https://frenchcloud.cam';

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final imdbId = await getImdbId(ctx, fetcher, id);
    final pageUrl = Uri.parse('$baseUrl/movie/${imdbId.id}');
    final html = await fetcher.text(ctx, pageUrl);
    return requireRustParseSourceHtml(this.id, html, referer: baseUrl);
  }
}
