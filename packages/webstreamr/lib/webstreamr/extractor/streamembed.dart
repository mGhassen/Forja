/// Port of webstreamr/src/extractor/StreamEmbed.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class StreamEmbed extends Extractor {
  StreamEmbed(super.fetcher);

  @override
  String get id => 'streamembed';
  @override
  String get label => 'StreamEmbed';
  @override
  Duration get ttl => const Duration(days: 3);

  @override
  bool supports(Context ctx, Uri url) =>
      RegExp(r'bullstream|mp4player|watch\.gxplayer').hasMatch(url.host);

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final html =
        await fetcher.text(ctx, url, FetcherRequestConfig(headers: headers));
    return requireRustExtractFromHtml(id, html, url.toString(), meta);
  }
}
