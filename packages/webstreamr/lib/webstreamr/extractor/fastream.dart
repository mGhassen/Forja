/// Port of webstreamr/src/extractor/Fastream.ts
library;

import '../errors.dart';
import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/media_flow_proxy.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

class Fastream extends Extractor {
  Fastream(super.fetcher);

  @override
  String get id => 'fastream';
  @override
  String get label => 'Fastream';
  @override
  bool get viaMediaFlowProxy => true;

  @override
  bool supports(Context ctx, Uri url) =>
      url.host.contains('fastream') && supportsMediaFlowProxy(ctx);

  @override
  Uri normalize(Uri url) => Uri.parse(
      url.toString().replaceFirst('/e/', '/embed-').replaceFirst('/d/', '/embed-'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final downloadUrl =
        Uri.parse(url.toString().replaceFirst('/embed-', '/d/'));
    final html = await fetcher.text(
        ctx, downloadUrl, FetcherRequestConfig(headers: headers));
    if (RegExp(r'No such file').hasMatch(html)) throw NotFoundError();

    final mfpJson = mediaFlowProxyConfigJson(ctx, headers)!;
    return requireRustExtractMfpFromHtml(
      id,
      '',
      url.toString(),
      meta,
      mfpJson,
      extraHtml: html,
    );
  }
}
