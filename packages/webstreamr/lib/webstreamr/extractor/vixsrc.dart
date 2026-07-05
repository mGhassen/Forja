/// Port of webstreamr/src/extractor/VixSrc.ts
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class VixSrc extends Extractor {
  VixSrc(super.fetcher);

  @override
  String get id => 'vixsrc';
  @override
  String get label => 'VixSrc';
  @override
  Duration get ttl => const Duration(hours: 6);

  @override
  bool supports(Context ctx, Uri url) => url.host.contains('vixsrc');

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final html = await fetcher.text(ctx, url);
    return requireRustExtractFromHtml(id, html, url.toString(), meta);
  }
}
