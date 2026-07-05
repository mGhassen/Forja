/// Port of webstreamr/src/extractor/Mixdrop.ts
library;

import '../errors.dart';
import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/media_flow_proxy.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class Mixdrop extends Extractor {
  Mixdrop(super.fetcher);

  @override
  String get id => 'mixdrop';
  @override
  String get label => 'Mixdrop';
  @override
  bool get viaMediaFlowProxy => true;

  @override
  bool supports(Context ctx, Uri url) =>
      RegExp(r'mixdrop|mixdrp|mixdroop|m1xdrop').hasMatch(url.host) &&
      supportsMediaFlowProxy(ctx);

  @override
  Uri normalize(Uri url) =>
      Uri.parse(url.toString().replaceFirst('/f/', '/e/'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final fileUrl = Uri.parse(url.toString().replaceFirst('/e/', '/f/'));
    final html = await fetcher.text(ctx, fileUrl);
    if (RegExp(r"can't find the (file|video)").hasMatch(html)) {
      throw NotFoundError();
    }

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
