/// Port of webstreamr/src/extractor/SuperVideo.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class SuperVideo extends Extractor {
  SuperVideo(super.fetcher);

  @override
  String get id => 'supervideo';
  @override
  String get label => 'SuperVideo';
  @override
  Duration get ttl => const Duration(hours: 3);

  @override
  bool supports(Context ctx, Uri url) => url.host.contains('supervideo');

  @override
  Uri normalize(Uri url) => Uri.parse(url
      .toString()
      .replaceFirst('/e/', '/')
      .replaceFirst('/k/', '/')
      .replaceFirst('/embed-', '/'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final html =
        await fetcher.text(ctx, url, FetcherRequestConfig(headers: headers));
    return requireRustExtractFromHtml(id, html, url.toString(), meta);
  }
}
