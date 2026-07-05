/// Port of webstreamr/src/extractor/LuluStream.ts
library;

import '../errors.dart';
import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/media_flow_proxy.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

const _kHosts = {
  '732eg54de642sa.sbs',
  'cdn1.site',
  'd00ds.site',
  'streamhihi.com',
};

class LuluStream extends Extractor {
  LuluStream(super.fetcher);

  @override
  String get id => 'lulustream';
  @override
  String get label => 'LuluStream';
  @override
  bool get viaMediaFlowProxy => true;

  @override
  bool supports(Context ctx, Uri url) {
    final ok = url.host.contains('lulu') || _kHosts.contains(url.host);
    return ok && supportsMediaFlowProxy(ctx);
  }

  @override
  Uri normalize(Uri url) {
    final segs = url.pathname.replaceAll(RegExp(r'/+$'), '').split('/');
    final videoId = segs.last;
    return url.replace(path: '/e/$videoId');
  }

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final fileUrl = Uri.parse(url.toString().replaceFirst('/e/', '/d/'));
    final html = await fetcher.text(
        ctx, fileUrl, FetcherRequestConfig(headers: headers));
    if (RegExp(r'No such file|File Not Found').hasMatch(html)) {
      throw NotFoundError();
    }

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

extension on Uri {
  String get pathname => path.isEmpty ? '/' : path;
}
