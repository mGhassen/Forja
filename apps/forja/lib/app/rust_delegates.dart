import 'dart:convert';

import 'package:forja_api/api/stremio_service.dart';
import 'package:forja_api/api/torrent_filter.dart';
import 'package:forja_api/api/kisskh_subtitle_decryptor.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/pastesh_decryptor.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:forja_scrapers/scrapers/scraper_parse.dart';
import 'package:forja_webstreamr/webstreamr/webstreamr_parse.dart';
import 'package:forja_webstreamr/webstreamr/utils/unpacker.dart';

/// App-layer delegates that cannot live in [ForjaEngine] (avoids forja_rust → forja_api cycle).
void installRustAppDelegates() {
  if (!ForjaEngine.isReady) return;

  TorrentFilterBackend.normalizeTitle =
      (title) => ForjaRust.instance.normalizeTorrentTitle(title);

  TorrentFilterBackend.parseSceneInfo = (title) {
    final m = jsonDecode(ForjaRust.instance.parseSceneInfoJson(title))
        as Map<String, dynamic>;
    return {
      'season': m['season'],
      'episode': m['episode'],
      'isSeasonPack': m['is_season_pack'] ?? false,
      'isMultiEpisode': m['is_multi_episode'] ?? false,
      'isMultiSeason': m['is_multi_season'] ?? false,
      'matchIndex': m['match_index'] ?? -1,
    };
  };

  StremioServiceBackend.buildResourceUrl = (addonUrl, resourcePath) =>
      ForjaRust.instance.buildStremioResourceUrl(addonUrl, resourcePath);

  StremioServiceBackend.splitAddonUrl = (url) {
    final m = jsonDecode(ForjaRust.instance.splitStremioAddonUrlJson(url))
        as Map<String, dynamic>;
    return (
      baseUrl: m['base_url'] as String,
      queryParams: m['query_params'] as String?,
    );
  };

  StremioServiceBackend.normalizeManifestUrl =
      (url) => ForjaRust.instance.normalizeStremioManifestUrl(url);

  StremioServiceBackend.parseManifestJson =
      (json) => ForjaRust.instance.parseStremioManifestJson(json);

  StremioServiceBackend.parseStreamsJson = (json) {
    final parsed = jsonDecode(ForjaRust.instance.parseStremioStreamsJson(json))
        as Map<String, dynamic>;
    if (parsed.containsKey('error')) return const [];
    final streams = parsed['streams'];
    return streams is List ? streams : const [];
  };

  StremioServiceBackend.parseSubtitlesJson = (json) {
    final parsed =
        jsonDecode(ForjaRust.instance.parseStremioSubtitlesJson(json))
            as Map<String, dynamic>;
    if (parsed.containsKey('error')) return const [];
    final subs = parsed['subtitles'];
    if (subs is! List) return const [];
    return subs
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
  };

  ScraperParseBackend.parseKnaben = (html) =>
      torrentRowsFromJson(ForjaRust.instance.parseKnabenHtmlJson(html));

  ScraperParseBackend.parseTpb = (html, source) => torrentRowsFromJson(
        ForjaRust.instance.parseTpbHtmlJson(html),
      ).map((row) => {...row, 'source': source}).toList();

  ScraperParseBackend.parseUindex = (html) =>
      torrentRowsFromJson(ForjaRust.instance.parseUindexHtmlJson(html));

  ScraperParseBackend.dedupTorrents = (results) => torrentRowsFromJson(
        ForjaRust.instance.dedupTorrentsJson(jsonEncode(results)),
      );

  PasteShDecryptorBackend.decryptRaw = (url, raw) =>
      ForjaRust.instance.decryptPasteResponse(url, raw);

  IptvClientBackend.decodeXtreamText =
      (text) => ForjaRust.instance.decodeXtreamText(text);

  IptvClientBackend.parseCategoriesJson =
      (json) => ForjaRust.instance.parseXtreamCategoriesJson(json);

  IptvClientBackend.parseStreamsJson = (json, section) =>
      ForjaRust.instance.parseXtreamStreamsJson(json, section);

  WebstreamrParseBackend.extractEmbedHtmlJson = (id, html, pageUrl) =>
      ForjaRust.instance.extractEmbedHtmlJson(id, html, pageUrl);

  WebstreamrParseBackend.extractVidsrcChainJson =
      (outer, rcp, prorcp) =>
          ForjaRust.instance.extractVidsrcChainJson(outer, rcp, prorcp);

  WebstreamrParseBackend.extractHubcloudLinksJson = (html, pageUrl) =>
      ForjaRust.instance.extractHubcloudLinksJson(html, pageUrl);

  WebstreamrParseBackend.extractMfpEmbedHtmlJson =
      (id, html, pageUrl, mfpConfigJson, extraHtml) =>
          ForjaRust.instance.extractMfpEmbedHtmlJson(
            id,
            html,
            pageUrl,
            mfpConfigJson,
            extraHtml: extraHtml,
          );

  WebstreamrParseBackend.resolveSourceJson = (sourceId, requestJson) =>
      ForjaRust.instance.resolveWebstreamrSourceJson(sourceId, requestJson);

  WebstreamrParseBackend.extractKinogerEpisodeUrlsJson =
      (html, seasonIndex, episodeIndex) =>
          ForjaRust.instance.extractKinogerEpisodeUrlsJson(
            html,
            seasonIndex,
            episodeIndex,
          );

  WebstreamrParseBackend.parseSourceHtmlJson = (sourceId, html, optsJson) =>
      ForjaRust.instance.parseWebstreamrSourceHtmlJson(
        sourceId,
        html,
        optsJson,
      );

  JsUnpackBackend.unpack = (source) {
    final out = ForjaRust.instance.unpackJs(source);
    return out.isEmpty ? null : out;
  };

  KissKhDecryptBackend.decryptBody = (body, sourceUrl) =>
      ForjaRust.instance.decryptKisskhBody(body, sourceUrl: sourceUrl);
}
