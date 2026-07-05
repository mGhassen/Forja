/// Port of webstreamr/src/extractor/Dropload.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class Dropload extends Extractor {
  Dropload(super.fetcher);

  @override
  String get id => 'dropload';
  @override
  String get label => 'Dropload';
  @override
  Duration get ttl => const Duration(hours: 3);

  @override
  bool supports(Context ctx, Uri url) =>
      RegExp(r'dropload|dr0pstream').hasMatch(url.host);

  @override
  Uri normalize(Uri url) => Uri.parse(url
      .toString()
      .replaceFirst('/d/', '/')
      .replaceFirst('/e/', '/')
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
