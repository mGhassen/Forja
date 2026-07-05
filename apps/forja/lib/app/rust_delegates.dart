import 'dart:convert';

import 'package:api/api/stremio_service.dart';
import 'package:api/api/torrent_filter.dart';
import 'package:api/api/kisskh_subtitle_decryptor.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/pastesh_decryptor.dart';
import 'package:rust/rust.dart';
import 'package:scrapers/scrapers/scraper_parse.dart';
import 'package:streaming/streaming.dart';
import 'package:webstreamr/webstreamr/webstreamr_parse.dart';
import 'package:webstreamr/webstreamr/utils/unpacker.dart';

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

  StremioServiceBackend.parseCatalogJson = (json) {
    final parsed =
        jsonDecode(ForjaRust.instance.parseStremioCatalogJson(json))
            as Map<String, dynamic>;
    if (parsed.containsKey('error')) return const [];
    final metas = parsed['metas'];
    if (metas is! List) return const [];
    return metas
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  };

  StremioServiceBackend.parseMetaJson = (json) {
    final parsed = jsonDecode(ForjaRust.instance.parseStremioMetaJson(json))
        as Map<String, dynamic>;
    if (parsed.containsKey('error')) return null;
    final meta = parsed['meta'];
    if (meta is! Map) return null;
    return Map<String, dynamic>.from(meta);
  };

  StremioServiceBackend.httpGet = (uri, {required timeout}) async {
    final raw = ForjaRust.instance.stremioHttpGet(
      uri.toString(),
      timeoutSecs: timeout.inSeconds,
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) {
      throw Exception(parsed['error'] as String? ?? 'HTTP error');
    }
    return (
      statusCode: parsed['status'] as int? ?? 0,
      body: parsed['body'] as String? ?? '',
    );
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

  IptvClientBackend.parseSeriesEpisodesJson =
      (json) => ForjaRust.instance.parseXtreamSeriesEpisodesJson(json);

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

  TorrentEngineBackend.start =
      (magnet) => ForjaRust.instance.torrentStart(magnet);
  TorrentEngineBackend.stop = ForjaRust.instance.torrentStop;
  TorrentEngineBackend.isRunning = ForjaRust.instance.torrentIsRunning;
  TorrentEngineBackend.statusJson = ForjaRust.instance.torrentStatusJson;
  TorrentEngineBackend.engineStart =
      (port) => ForjaRust.instance.torrentEngineStart(port);
  TorrentEngineBackend.enginePort = ForjaRust.instance.torrentEnginePort;
  TorrentEngineBackend.engineStop = ForjaRust.instance.torrentEngineStop;
  TorrentEngineBackend.streamTorrent = (magnet, {season, episode, fileIdx}) {
    final json = ForjaRust.instance.torrentStreamJson(
      magnet,
      season: season,
      episode: episode,
      fileIdx: fileIdx,
    );
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return null;
    final url = parsed['url'];
    return url is String && url.isNotEmpty ? url : null;
  };
  TorrentEngineBackend.listFiles = (magnet) {
    final json = ForjaRust.instance.torrentListFilesJson(magnet);
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return const [];
    final files = parsed['files'];
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map(
          (f) => TorrentFileEntry(
            index: (f['index'] as num?)?.toInt() ?? 0,
            name: f['name'] as String? ?? '',
            size: (f['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  };
}
