/// Port of webstreamr/src/extractor/SaveFiles.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class SaveFiles extends Extractor {
  SaveFiles(super.fetcher);

  @override
  String get id => 'savefiles';
  @override
  String get label => 'SaveFiles';
  @override
  Duration get ttl => const Duration(hours: 6);

  @override
  bool supports(Context ctx, Uri url) =>
      RegExp(r'savefiles|streamhls').hasMatch(url.host);

  @override
  Uri normalize(Uri url) => Uri.parse(url
      .toString()
      .replaceFirst('/e/', '/')
      .replaceFirst('/d/', '/'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final html =
        await fetcher.text(ctx, url, FetcherRequestConfig(headers: headers));
    return requireRustExtractFromHtml(id, html, url.toString(), meta);
  }
}
