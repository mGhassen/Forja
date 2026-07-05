/// Port of webstreamr/src/extractor/Uqload.ts
library;

import '../errors.dart';
import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/media_flow_proxy.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class Uqload extends Extractor {
  Uqload(super.fetcher);

  @override
  String get id => 'uqload';
  @override
  String get label => 'Uqload';
  @override
  bool get viaMediaFlowProxy => true;

  @override
  bool supports(Context ctx, Uri url) =>
      url.host.contains('uqload') && supportsMediaFlowProxy(ctx);

  @override
  Uri normalize(Uri url) =>
      Uri.parse(url.toString().replaceFirst('/embed-', '/'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final html = await fetcher.text(ctx, url);
    if (RegExp(r'File Not Found').hasMatch(html)) throw NotFoundError();

    final mfpJson = mediaFlowProxyConfigJson(ctx, const {})!;
    return requireRustExtractMfpFromHtml(
      id,
      html,
      url.toString(),
      meta,
      mfpJson,
    );
  }
}
