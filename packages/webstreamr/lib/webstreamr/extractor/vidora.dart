/// Port of webstreamr/src/extractor/Vidora.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class Vidora extends Extractor {
  Vidora(super.fetcher);

  @override
  String get id => 'vidora';
  @override
  String get label => 'Vidora';
  @override
  Duration get ttl => const Duration(hours: 12);

  @override
  bool supports(Context ctx, Uri url) => url.host.contains('vidora');

  @override
  Uri normalize(Uri url) =>
      Uri.parse(url.toString().replaceFirst('/embed/', '/'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final html = await fetcher.text(ctx, url);
    return requireRustExtractFromHtml(id, html, url.toString(), meta);
  }
}
