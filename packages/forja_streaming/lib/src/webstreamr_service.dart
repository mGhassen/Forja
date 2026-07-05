import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forja_core/models/stream_source.dart';
import 'local_server_service.dart';
import 'package:forja_webstreamr/webstreamr/extractor/doodstream.dart';
import 'package:forja_webstreamr/webstreamr/extractor/dropload.dart';
import 'package:forja_webstreamr/webstreamr/extractor/external_url.dart';
import 'package:forja_webstreamr/webstreamr/extractor/extractor.dart';
import 'package:forja_webstreamr/webstreamr/extractor/extractor_registry.dart';
import 'package:forja_webstreamr/webstreamr/extractor/fastream.dart';
import 'package:forja_webstreamr/webstreamr/extractor/filelions.dart';
import 'package:forja_webstreamr/webstreamr/extractor/filemoon.dart';
import 'package:forja_webstreamr/webstreamr/extractor/fsst.dart';
import 'package:forja_webstreamr/webstreamr/extractor/hubcloud.dart';
import 'package:forja_webstreamr/webstreamr/extractor/hubdrive.dart';
import 'package:forja_webstreamr/webstreamr/extractor/kinoger.dart' as ext_kinoger;
import 'package:forja_webstreamr/webstreamr/extractor/lulustream.dart';
import 'package:forja_webstreamr/webstreamr/extractor/mixdrop.dart';
import 'package:forja_webstreamr/webstreamr/extractor/rgshows.dart' as ext_rgshows;
import 'package:forja_webstreamr/webstreamr/extractor/savefiles.dart';
import 'package:forja_webstreamr/webstreamr/extractor/streamembed.dart';
import 'package:forja_webstreamr/webstreamr/extractor/streamtape.dart';
import 'package:forja_webstreamr/webstreamr/extractor/supervideo.dart';
import 'package:forja_webstreamr/webstreamr/extractor/uqload.dart';
import 'package:forja_webstreamr/webstreamr/extractor/vidora.dart';
import 'package:forja_webstreamr/webstreamr/extractor/vidsrc.dart' as ext_vidsrc;
import 'package:forja_webstreamr/webstreamr/extractor/vixsrc.dart' as ext_vixsrc;
import 'package:forja_webstreamr/webstreamr/extractor/voe.dart';
import 'package:forja_webstreamr/webstreamr/extractor/youtube.dart';
import 'package:forja_webstreamr/webstreamr/source/cinehdplus.dart';
import 'package:forja_webstreamr/webstreamr/source/cuevana.dart';
import 'package:forja_webstreamr/webstreamr/source/einschalten.dart';
import 'package:forja_webstreamr/webstreamr/source/eurostreaming.dart';
import 'package:forja_webstreamr/webstreamr/source/fourkhdhub.dart';
import 'package:forja_webstreamr/webstreamr/source/frembed.dart';
import 'package:forja_webstreamr/webstreamr/source/frenchcloud.dart';
import 'package:forja_webstreamr/webstreamr/source/hdhub4u.dart';
import 'package:forja_webstreamr/webstreamr/source/vegamovies.dart';
import 'package:forja_webstreamr/webstreamr/source/homecine.dart';
import 'package:forja_webstreamr/webstreamr/source/kinoger.dart';
import 'package:forja_webstreamr/webstreamr/source/kokoshka.dart';
import 'package:forja_webstreamr/webstreamr/source/megakino.dart';
import 'package:forja_webstreamr/webstreamr/source/meinecloud.dart';
import 'package:forja_webstreamr/webstreamr/source/mostraguarda.dart';
import 'package:forja_webstreamr/webstreamr/source/movix.dart';
import 'package:forja_webstreamr/webstreamr/source/rgshows.dart';
import 'package:forja_webstreamr/webstreamr/source/source.dart';
import 'package:forja_webstreamr/webstreamr/source/streamkiste.dart';
import 'package:forja_webstreamr/webstreamr/source/verhdlink.dart';
import 'package:forja_webstreamr/webstreamr/source/vidsrc.dart';
import 'package:forja_webstreamr/webstreamr/source/vixsrc.dart';
import 'package:forja_webstreamr/webstreamr/stream_resolver.dart';
import 'package:forja_webstreamr/webstreamr/types.dart';
import 'package:forja_webstreamr/webstreamr/utils/config.dart';
import 'package:forja_webstreamr/webstreamr/utils/env.dart';
import 'package:forja_webstreamr/webstreamr/utils/fetcher.dart';
import 'package:forja_webstreamr/webstreamr/utils/id.dart';
import 'package:forja_api/api/webstreamr_settings.dart';

/// Native, on-device port of webstreamr — does NOT hit any remote addon.
/// Builds Stremio-shaped streams locally via the 20-source / 25-extractor
/// pipeline and flattens them to [StreamSource] for the existing player UI.
class WebStreamrService {
  static final WebStreamrService _instance = WebStreamrService._internal();
  factory WebStreamrService() => _instance;
  WebStreamrService._internal();

  static bool _initialized = false;
  static late Fetcher _fetcher;
  static late ExtractorRegistry _registry;
  static late List<Source> _sources;
  static late StreamResolver _resolver;

  /// Call once at app start (safe to call repeatedly — re-applies env).
  static Future<void> init() async {
    final tmdbToken = await WebStreamrSettings.getTmdbAccessToken();
    WsEnv.load({
      'MANIFEST_ID': 'webstreamr',
      'MANIFEST_NAME': 'WebStreamr',
      'NODE_ENV': kReleaseMode ? 'production' : 'development',
      if (tmdbToken != null && tmdbToken.isNotEmpty)
        'TMDB_ACCESS_TOKEN': tmdbToken,
    });

    if (_initialized) return;
    _initialized = true;

    _fetcher = Fetcher(logger: (msg) => debugPrint('[WS] $msg'));

    final hubCloud = HubCloud(_fetcher);

    final extractors = <Extractor>[
      DoodStream(_fetcher),
      Dropload(_fetcher),
      Fastream(_fetcher),
      FileLions(_fetcher),
      FileMoon(_fetcher),
      Fsst(_fetcher),
      hubCloud,
      HubDrive(_fetcher, hubCloud),
      ext_kinoger.KinoGer(_fetcher),
      LuluStream(_fetcher),
      Mixdrop(_fetcher),
      ext_rgshows.RgShows(_fetcher),
      SaveFiles(_fetcher),
      StreamEmbed(_fetcher),
      Streamtape(_fetcher),
      SuperVideo(_fetcher),
      Uqload(_fetcher),
      Vidora(_fetcher),
      ext_vidsrc.VidSrc(_fetcher, const [
        'vidsrcme.ru',
        'vidsrcme.su',
        'vidsrc-me.ru',
        'vidsrc-me.su',
        'vidsrc-embed.ru',
        'vidsrc-embed.su',
        'vsrc.su',
      ]),
      ext_vixsrc.VixSrc(_fetcher),
      Voe(_fetcher),
      YouTube(_fetcher),
      ExternalUrl(_fetcher), // must remain last
    ];

    _registry = ExtractorRegistry(
        (lvl, msg) => debugPrint('[WS:$lvl] $msg'), extractors);

    _sources = <Source>[
      // multi
      FourKHDHubSource(_fetcher),
      HDHub4uSource(_fetcher),
      VegaMoviesSource(_fetcher),
      VixSrcSource(_fetcher),
      VidSrcSource(_fetcher),
      RgShowsSource(_fetcher),
      // AL
      KokoshkaSource(_fetcher),
      // ES / MX
      CineHDPlusSource(_fetcher),
      CuevanaSource(_fetcher),
      HomeCineSource(_fetcher),
      VerHdLinkSource(_fetcher),
      // DE
      EinschaltenSource(_fetcher),
      KinoGerSource(_fetcher),
      MegaKinoSource(_fetcher),
      MeineCloudSource(_fetcher),
      StreamKisteSource(_fetcher),
      // FR
      FrembedSource(_fetcher),
      FrenchCloudSource(_fetcher),
      MovixSource(_fetcher),
      // IT
      EurostreamingSource(_fetcher),
      MostraGuardaSource(_fetcher),
    ];

    _resolver =
        StreamResolver((lvl, msg) => debugPrint('[WS:$lvl] $msg'), _registry);
  }

  /// Drop-in replacement for the old remote `getStreams`.
  /// Accepts an IMDb ID (preferred) and optional TMDB ID.
  Future<List<StreamSource>> getStreams({
    required String imdbId,
    bool isMovie = true,
    int? season,
    int? episode,
    int? tmdbId,
  }) async {
    try {
      await init();

      final type = isMovie ? 'movie' : 'series';
      final base = imdbId.split(':').first;
      final Id id;
      if (RegExp(r'^tt\d+$').hasMatch(base)) {
        final raw = isMovie
            ? imdbId
            : '$imdbId:${season ?? 1}:${episode ?? 1}';
        id = ImdbId.fromString(raw);
      } else if (tmdbId != null) {
        final raw = isMovie
            ? '$tmdbId'
            : '$tmdbId:${season ?? 1}:${episode ?? 1}';
        id = TmdbId.fromString(raw);
      } else {
        debugPrint('[WebStreamrService] No valid IMDb/TMDB id for "$imdbId"');
        return [];
      }

      final ctx = await _buildContext(id);
      // Mirror upstream StreamController: only run sources that have at
      // least one country code enabled in the user's config. Avoids wasting
      // network on sources whose results would be filtered out anyway.
      final activeSources = _sources
          .where((s) =>
              s.countryCodes.any((cc) => ctx.config.containsKey(cc.name)))
          .toList();
      debugPrint(
          '[WebStreamrService] ${activeSources.length}/${_sources.length} sources active for config ${ctx.config.keys.where((k) => k.length == 2 || k == 'multi').toList()}');
      final res = await _resolver.resolve(ctx, activeSources, type, id);

      final out = <StreamSource>[];
      for (final s in res.streams) {
        final url = (s['url'] ?? s['externalUrl']) as String?;
        if (url == null || url.isEmpty) continue;
        final name = (s['name'] ?? '') as String;
        final title = (s['title'] ?? '') as String;
        final display = name.isNotEmpty ? '$name\n$title' : title;
        Map<String, String>? headers;
        final bh = s['behaviorHints'];
        if (bh is Map &&
            bh['proxyHeaders'] is Map &&
            (bh['proxyHeaders'] as Map)['request'] is Map) {
          headers = Map<String, String>.from(
              (bh['proxyHeaders'] as Map)['request'] as Map);
        }
        // Some sources (e.g. RG Shows / 1shows.app) deliver MPEG-TS
        // segments wrapped in a fake PNG container on TikTok CDN. media_kit
        // can't decode that, so we route the stream through our local HLS
        // proxy with PNG-stripping enabled.
        var finalUrl = url;
        if (Uri.tryParse(url)?.host.contains('1shows.app') ?? false) {
          final ls = LocalServerService();
          if (ls.port != 0) {
            finalUrl = ls.getHlsProxyUrl(url, headers ?? {}, stripMode: 'png');
            // After proxying, the player no longer needs the upstream
            // referer/origin — the local proxy injects them.
            headers = null;
          }
        }
        out.add(StreamSource(
          url: finalUrl,
          title: display,
          type: 'video',
          headers: headers,
        ));
      }
      return out;
    } catch (e, st) {
      debugPrint('[WebStreamrService] Exception: $e\n$st');
      return [];
    }
  }

  Future<Context> _buildContext(Id id) async {
    final config = <String, String>{};
    final enabledCC = await WebStreamrSettings.getEnabledCountryCodes();
    for (final cc in enabledCC) {
      config[cc] = 'on';
    }
    config['multi'] = 'on';

    final mfpUrl = await WebStreamrSettings.getMediaFlowProxyUrl();
    final mfpPwd = await WebStreamrSettings.getMediaFlowProxyPassword();
    if (mfpUrl != null && mfpUrl.isNotEmpty) {
      config['mediaFlowProxyUrl'] = mfpUrl;
      if (mfpPwd != null) config['mediaFlowProxyPassword'] = mfpPwd;
    }

    final flareUrl = await WebStreamrSettings.getFlareSolverrUrl();
    if (flareUrl != null && flareUrl.isNotEmpty) {
      WsEnv.set('FLARESOLVERR_URL', flareUrl);
    }

    for (final exId in await WebStreamrSettings.getDisabledExtractors()) {
      config[disableExtractorConfigKey(exId)] = 'on';
    }
    for (final res in await WebStreamrSettings.getExcludedResolutions()) {
      config[excludeResolutionConfigKey(res)] = 'on';
    }

    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('webstreamr_client_ip');

    return Context(
      hostUrl: Uri.parse('http://localhost'),
      id: id.toString(),
      ip: ip,
      config: config,
    );
  }
}
