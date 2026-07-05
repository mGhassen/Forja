/// Port of webstreamr/src/extractor/Fsst.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class Fsst extends Extractor {
  Fsst(super.fetcher);

  @override
  String get id => 'fsst';
  @override
  String get label => 'Fsst';
  @override
  Duration get ttl => const Duration(hours: 3);

  @override
  bool supports(Context ctx, Uri url) => url.host.contains('fsst');

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final html = await fetcher.text(ctx, url,
        FetcherRequestConfig(headers: headers, noProxyHeaders: true));
    final rust = requireRustExtractFromHtml(id, html, url.toString(), meta);
    final r = rust.first;
    final finalUrl = await fetcher.getFinalRedirectUrl(
      ctx,
      r.url,
      FetcherRequestConfig(headers: headers, noProxyHeaders: true),
      1,
    );
    return [
      InternalUrlResult(
        url: finalUrl,
        format: r.format,
        meta: r.meta,
        requestHeaders: r.requestHeaders,
      ),
    ];
  }
}
