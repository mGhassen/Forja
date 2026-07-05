/// Port of webstreamr/src/source/MegaKino.ts. The Fetcher's internal cookie
/// jar handles the Set-Cookie automatically, so we just need to do the HEAD
/// then the search.
library;

import 'package:html/parser.dart' as html_parser;

import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class MegaKinoSource extends Source {
  MegaKinoSource(super.fetcher);

  @override
  String get id => 'megakino';
  @override
  String get label => 'MegaKino';
  @override
  List<String> get contentTypes => const ['movie'];
  @override
  List<CountryCode> get countryCodes => const [CountryCode.de];
  @override
  String get baseUrl => 'https://megakino1.to';

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
    final imdbId = await getImdbId(ctx, fetcher, id);
    final base = await _getBaseUrl(ctx);

    await fetcher.head(ctx, base.replace(queryParameters: {'yg': 'token'}));

    final pageUrl = await _fetchPageUrl(ctx, imdbId, base);
    if (pageUrl == null) return const [];

    final html = await fetcher.text(ctx, pageUrl);
    return requireRustParseSourceHtml(this.id, html, referer: pageUrl.toString());
  }

  Future<Uri?> _fetchPageUrl(Context ctx, ImdbId imdbId, Uri base) async {
    final origin = '${base.scheme}://${base.host}';
    final form =
        'do=search&subaction=search&story=${Uri.encodeComponent(imdbId.id)}';
    final html = await fetcher.textPost(
        ctx,
        base,
        form,
        FetcherRequestConfig(headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': origin,
        }));
    final doc = html_parser.parse(html);
    final href =
        doc.querySelector('#dle-content a[href].poster')?.attributes['href'];
    if (href == null) return null;
    return Uri.parse(href).hasScheme
        ? Uri.parse(href)
        : base.resolve(href);
  }
}
