/// Port of webstreamr/src/extractor/KinoGer.ts. Needs AES-128-CBC + PKCS7.
library;

import '../types.dart';
import '../utils/fetcher.dart';
import '../webstreamr_parse.dart';
import 'extractor.dart';

const _kHosts = {
  'asianembed.cam',
  'disneycdn.net',
  'dzo.vidplayer.live',
  'filedecrypt.link',
  'filma365.strp2p.site',
  'flimmer.rpmvip.com',
  'flixfilmesonline.strp2p.site',
  'kinoger.p2pplay.pro',
  'kinoger.re',
  'moflix.rpmplay.xyz',
  'moflix.upns.xyz',
  'player.upn.one',
  'securecdn.shop',
  'shiid4u.upn.one',
  'srbe84.vidplayer.live',
  'strp2p.site',
  't1.p2pplay.pro',
  'tuktuk.rpmvid.com',
  'ultrastream.online',
  'videoland.cfd',
  'videoshar.uns.bio',
  'w1tv.xyz',
  'wasuytm.store',
};

class KinoGer extends Extractor {
  KinoGer(super.fetcher);

  @override
  String get id => 'kinoger';
  @override
  String get label => 'KinoGer';
  @override
  Duration get ttl => const Duration(hours: 6);

  @override
  bool supports(Context ctx, Uri url) => _kHosts.contains(url.host);

  @override
  Uri normalize(Uri url) {
    final origin = '${url.scheme}://${url.host}';
    return Uri.parse('$origin/api/v1/video?id=${url.fragment}');
  }

  @override
  Future<List<InternalUrlResult>> extractInternal(
      Context ctx, Uri url, Meta meta) async {
    final origin = '${url.scheme}://${url.host}';
    final headers = {
      'Origin': origin,
      'Referer': '$origin/',
      'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    };
    final hex = await fetcher.text(ctx, url,
        FetcherRequestConfig(headers: headers));
    return requireRustExtractFromHtml(id, hex, url.toString(), meta);
  }
}
