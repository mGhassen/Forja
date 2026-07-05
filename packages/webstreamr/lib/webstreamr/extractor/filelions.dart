/// Port of webstreamr/src/extractor/FileLions.ts
library;

import '../errors.dart';
import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/media_flow_proxy.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

const _kHosts = {
  '6sfkrspw4u.sbs',
  'ajmidyadfihayh.sbs',
  'alhayabambi.sbs',
  'anime7u.com',
  'azipcdn.com',
  'bingezove.com',
  'callistanise.com',
  'coolciima.online',
  'dhtpre.com',
  'dingtezuni.com',
  'dintezuvio.com',
  'e4xb5c2xnz.sbs',
  'egsyxutd.sbs',
  'fdewsdc.sbs',
  'gsfomqu.sbs',
  'javplaya.com',
  'katomen.online',
  'lumiawatch.top',
  'minochinos.com',
  'mivalyo.com',
  'moflix-stream.click',
  'motvy55.store',
  'movearnpre.com',
  'peytonepre.com',
  'ryderjet.com',
  'smoothpre.com',
  'taylorplayer.com',
  'techradar.ink',
  'videoland.sbs',
  'vidhide.com',
  'vidhide.fun',
  'vidhidefast.com',
  'vidhidehub.com',
  'vidhideplus.com',
  'vidhidepre.com',
  'vidhidepro.com',
  'vidhidevip.com',
};

class FileLions extends Extractor {
  FileLions(super.fetcher);

  @override
  String get id => 'filelions';
  @override
  String get label => 'FileLions';
  @override
  bool get viaMediaFlowProxy => true;

  @override
  bool supports(Context ctx, Uri url) {
    final ok = RegExp(r'.*lions?').hasMatch(url.host) || _kHosts.contains(url.host);
    return ok && supportsMediaFlowProxy(ctx);
  }

  @override
  Uri normalize(Uri url) => Uri.parse(url
      .toString()
      .replaceFirst('/v/', '/f/')
      .replaceFirst('/download/', '/f/')
      .replaceFirst('/file/', '/f/'));

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    final html =
        await fetcher.text(ctx, url, FetcherRequestConfig(headers: headers));
    if (html.contains('This video can be watched as embed only')) {
      return extractInternal(
          ctx, Uri.parse(url.toString().replaceFirst('/f/', '/v/')), meta);
    }
    if (RegExp(r'File Not Found|deleted by administration').hasMatch(html)) {
      throw NotFoundError();
    }

    try {
      final next = requireRustNextUrl(id, html, url.toString());
      return extractInternal(ctx, Uri.parse(next), meta);
    } on NotFoundError {
      // continue to MFP extraction
    }

    final mfpJson = mediaFlowProxyConfigJson(ctx, headers)!;
    return requireRustExtractMfpFromHtml(
      id,
      html,
      url.toString(),
      meta,
      mfpJson,
    );
  }
}
