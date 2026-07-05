/// Port of webstreamr/src/extractor/HubCloud.ts
library;

import 'package:html/parser.dart' as html_parser;

import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/language.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class HubCloud extends Extractor {
  HubCloud(super.fetcher);

  @override
  String get id => 'hubcloud';
  @override
  String get label => 'HubCloud';
  @override
  Duration get ttl => const Duration(hours: 12);
  @override
  int? get cacheVersion => 1;

  @override
  bool supports(Context ctx, Uri url) =>
      url.host.contains('hubcloud') || url.host.contains('vcloud');

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final redirectHtml =
        await fetcher.text(ctx, url, FetcherRequestConfig(headers: headers));

    final next = requireRustNextUrl(id, redirectHtml, url.toString());
    final linksHeaders = {'Referer': url.toString()};
    final linksHtml = await fetcher.text(
        ctx, Uri.parse(next), FetcherRequestConfig(headers: linksHeaders));
    return _withCountryCodes(
      requireRustExtractHubcloudLinks(linksHtml, url.toString(), meta),
      linksHtml,
      meta,
    );
  }

  List<InternalUrlResult> _withCountryCodes(
    List<InternalUrlResult> rows,
    String linksHtml,
    Meta meta,
  ) {
    final title = html_parser.parse(linksHtml).querySelector('title')?.text.trim() ?? '';
    final ccs = <CountryCode>{
      ...?meta.countryCodes,
      ...findCountryCodes(title),
    }.toList();
    return rows
        .map((r) => InternalUrlResult(
              url: r.url,
              format: r.format,
              isExternal: r.isExternal,
              ytId: r.ytId,
              error: r.error,
              label: r.label,
              meta: (r.meta ?? meta).clone()..countryCodes = ccs,
              requestHeaders: r.requestHeaders,
            ))
        .toList();
  }
}
