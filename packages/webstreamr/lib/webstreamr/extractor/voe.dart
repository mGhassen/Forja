/// Port of webstreamr/src/extractor/Voe.ts
library;

import '../errors.dart';
import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/height.dart';
import '../utils/media_flow_proxy.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

const _kHosts = {
  '19turanosephantasia.com', '20demidistance9elongations.com',
  '30sensualizeexpression.com', '321naturelikefurfuroid.com',
  '35volitantplimsoles5.com', '449unceremoniousnasoseptal.com',
  '745mingiestblissfully.com', 'adrianmissionminute.com',
  'alleneconomicmatter.com', 'antecoxalbobbing1010.com',
  'apinchcaseation.com', 'audaciousdefaulthouse.com', 'availedsmallest.com',
  'bigclatterhomesguideservice.com', 'boonlessbestselling244.com',
  'bradleyviewdoctor.com', 'brittneystandardwestern.com',
  'brucevotewithin.com', 'christopheruntilpoint.com', 'chromotypic.com',
  'chuckle-tube.com', 'cindyeyefinal.com', 'counterclockwisejacky.com',
  'crownmakermacaronicism.com', 'crystaltreatmenteast.com',
  'cyamidpulverulence530.com', 'diananatureforeign.com',
  'donaldlineelse.com', 'edwardarriveoften.com', 'erikcoldperson.com',
  'figeterpiazine.com', 'fittingcentermondaysunday.com',
  'fraudclatterflyingcar.com', 'gamoneinterrupted.com',
  'generatesnitrosate.com', 'goofy-banana.com', 'graceaddresscommunity.com',
  'greaseball6eventual20.com', 'guidon40hyporadius9.com',
  'heatherdiscussionwhen.com', 'housecardsummerbutton.com',
  'jamessoundcost.com', 'jamiesamewalk.com', 'jasminetesttry.com',
  'jayservicestuff.com', 'jennifercertaindevelopment.com',
  'jilliandescribecompany.com', 'johnalwayssame.com',
  'jonathansociallike.com', 'josephseveralconcern.com',
  'kathleenmemberhistory.com', 'kellywhatcould.com',
  'kennethofficialitem.com', 'kinoger.ru', 'kristiesoundsimply.com',
  'lancewhosedifficult.com', 'launchreliantcleaverriver.com',
  'lauradaydo.com', 'lisatrialidea.com', 'loriwithinfamily.com',
  'lukecomparetwo.com', 'lukesitturn.com', 'mariatheserepublican.com',
  'matriculant401merited.com', 'maxfinishseveral.com',
  'metagnathtuggers.com', 'michaelapplysome.com', 'mikaylaarealike.com',
  'nathanfromsubject.com', 'nectareousoverelate.com', 'nonesnanking.com',
  'paulkitchendark.com', 'realfinanceblogcenter.com', 'rebeccaneverbase.com',
  'reputationsheriffkennethsand.com', 'richardsignfish.com',
  'roberteachfinal.com', 'robertordercharacter.com', 'robertplacespace.com',
  'sandratableother.com', 'sandrataxeight.com', 'scatch176duplicities.com',
  'sethniceletter.com', 'shannonpersonalcost.com', 'simpulumlamerop.com',
  'smoki.cc', 'stevenimaginelittle.com', 'strawberriesporail.com',
  'telyn610zoanthropy.com', 'timberwoodanotia.com', 'toddpartneranimal.com',
  'toxitabellaeatrebates306.com', 'uptodatefinishconferenceroom.com',
  'v-o-e-unblock.com', 'valeronevijao.com', 'walterprettytheir.com',
  'wolfdyslectic.com', 'yodelswartlike.com',
};

class Voe extends Extractor {
  Voe(super.fetcher);

  @override
  String get id => 'voe';
  @override
  String get label => 'VOE';
  @override
  bool get viaMediaFlowProxy => true;

  @override
  bool supports(Context ctx, Uri url) {
    final ok = url.host.contains('voe') || _kHosts.contains(url.host);
    return ok && supportsMediaFlowProxy(ctx);
  }

  @override
  Uri normalize(Uri url) {
    final segs = url.path.replaceAll(RegExp(r'/+$'), '').split('/');
    return url.replace(path: '/${segs.last}');
  }

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final headers = {'Referer': meta.referer ?? url.toString()};
    String html;
    try {
      html = await fetcher.text(
          ctx, url, FetcherRequestConfig(headers: headers));
    } on NotFoundError {
      if (!url.toString().contains('/e/')) {
        return extractInternal(
            ctx,
            url.replace(path: '/e${url.path}'),
            meta);
      }
      rethrow;
    }

    try {
      final next = requireRustNextUrl(id, html, url.toString());
      return extractInternal(ctx, Uri.parse(next), meta);
    } on NotFoundError {
      // continue to MFP extraction
    }

    if (RegExp(r'An error occurred during encoding').hasMatch(html)) {
      throw NotFoundError();
    }

    final mfpJson = mediaFlowProxyConfigJson(ctx, headers)!;
    final rust = requireRustExtractMfpFromHtml(
      id,
      html,
      url.toString(),
      meta,
      mfpJson,
    );
    if (rust.first.meta?.height != null) return rust;
    final height = meta.height ??
        await guessHeightFromPlaylist(
            ctx, fetcher, rust.first.url, FetcherRequestConfig());
    if (height == null) return rust;
    return rust
        .map((r) => InternalUrlResult(
              url: r.url,
              format: r.format,
              isExternal: r.isExternal,
              ytId: r.ytId,
              error: r.error,
              label: r.label,
              meta: (r.meta ?? meta).clone()..height = height,
              requestHeaders: r.requestHeaders,
            ))
        .toList();
  }
}
