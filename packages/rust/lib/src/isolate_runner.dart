import 'engine_worker.dart';

// ── WebStreamr ──────────────────────────────────────────────────────────────

Future<String> runWebstreamrGetStreamsJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.webstreamrGetStreams,
      {'requestJson': requestJson},
    );

// ── Stremio ─────────────────────────────────────────────────────────────────

Future<String> runStremioHttpGet(String url, {int timeoutSecs = 15}) =>
    EngineWorkerPool.run(
      EngineJobKind.stremioHttpGet,
      {'url': url, 'timeoutSecs': timeoutSecs},
    );

// ── Stream extractors ───────────────────────────────────────────────────────

Future<String> runResolveVidsrcEmbedJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.resolveVidsrcEmbed,
      {'requestJson': requestJson},
    );

Future<String> runOpensslAesDecryptJson(
  String intermediate, {
  String passphrase = '',
}) =>
    EngineWorkerPool.run(
      EngineJobKind.opensslAesDecrypt,
      {'b64': intermediate, 'passphrase': passphrase},
    );

// ── Torrent search / filter ─────────────────────────────────────────────────

Future<String> runSearchTorrentsJson(String query) => EngineWorkerPool.run(
      EngineJobKind.searchTorrents,
      {'query': query},
    );

Future<String> runFilterTorrentsJson(
  String resultsJson,
  String showTitle, {
  int requiredSeason = -1,
  int requiredEpisode = -1,
}) =>
    EngineWorkerPool.run(
      EngineJobKind.filterTorrents,
      {
        'resultsJson': resultsJson,
        'showTitle': showTitle,
        'requiredSeason': requiredSeason,
        'requiredEpisode': requiredEpisode,
      },
    );

Future<String> runSortTorrentsJson(String resultsJson, String preference) =>
    EngineWorkerPool.run(
      EngineJobKind.sortTorrents,
      {'resultsJson': resultsJson, 'preference': preference},
    );

// ── Parsers / decrypt ───────────────────────────────────────────────────────

Future<String> runParseM3uJson(String content) => EngineWorkerPool.run(
      EngineJobKind.parseM3u,
      {'content': content},
    );

Future<String> runParseHlsMasterJson(String masterUrl, String body) =>
    EngineWorkerPool.run(
      EngineJobKind.parseHlsMaster,
      {'masterUrl': masterUrl, 'body': body},
    );

Future<String> runDecryptKisskhBody(String body, {String? sourceUrl}) =>
    EngineWorkerPool.run(
      EngineJobKind.decryptKisskh,
      {'body': body, 'sourceUrl': sourceUrl},
    );

// ── IPTV HTTP / xtream / probe ──────────────────────────────────────────────

Future<String> runHttpGetJson(
  String url, {
  int timeoutSecs = 15,
  String headersJson = '{}',
}) =>
    EngineWorkerPool.run(
      EngineJobKind.httpGet,
      {
        'url': url,
        'timeoutSecs': timeoutSecs,
        'headersJson': headersJson,
      },
    );

Future<String> runHttpPostJson(
  String url, {
  int timeoutSecs = 15,
  String headersJson = '{}',
  String body = '',
}) =>
    EngineWorkerPool.run(
      EngineJobKind.httpPost,
      {
        'url': url,
        'timeoutSecs': timeoutSecs,
        'headersJson': headersJson,
        'body': body,
      },
    );

Future<String> runParseXtreamCategoriesJson(String json) =>
    EngineWorkerPool.run(
      EngineJobKind.parseXtreamCategories,
      {'json': json},
    );

Future<String> runParseXtreamStreamsJson(String json, String section) =>
    EngineWorkerPool.run(
      EngineJobKind.parseXtreamStreams,
      {'json': json, 'section': section},
    );

Future<String> runParseXtreamSeriesEpisodesJson(String json) =>
    EngineWorkerPool.run(
      EngineJobKind.parseXtreamSeriesEpisodes,
      {'json': json},
    );

Future<String> runIptvProbeStreamJson(String url, {int timeoutSecs = 8}) =>
    EngineWorkerPool.run(
      EngineJobKind.iptvProbeStream,
      {'url': url, 'timeoutSecs': timeoutSecs},
    );

Future<String> runDecryptPasteResponse(
  String urlWithHash,
  String rawResponse,
) =>
    EngineWorkerPool.run(
      EngineJobKind.decryptPasteResponse,
      {'urlWithHash': urlWithHash, 'rawResponse': rawResponse},
    );
