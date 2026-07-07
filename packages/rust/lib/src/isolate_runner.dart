import 'engine_jobs.dart';
import 'engine_worker.dart';

// ── Long I/O — Rust tokio jobs (main isolate stays free) ────────────────────

Future<String> runWebstreamrGetStreamsJson(String requestJson) =>
    EngineJobs.run(
      EngineAsyncJob.webstreamrGetStreams,
      {'requestJson': requestJson},
    );

Future<String> runStremioHttpGet(String url, {int timeoutSecs = 15}) =>
    EngineJobs.run(
      EngineAsyncJob.stremioHttpGet,
      {'url': url, 'timeout_secs': timeoutSecs},
    );

Future<String> runResolveVidsrcEmbedJson(String requestJson) =>
    EngineJobs.run(
      EngineAsyncJob.resolveVidsrcEmbed,
      {'requestJson': requestJson},
    );

Future<String> runSearchTorrentsJson(String query) => EngineJobs.run(
      EngineAsyncJob.searchTorrents,
      {'query': query},
    );

Future<String> runHttpGetJson(
  String url, {
  int timeoutSecs = 15,
  String headersJson = '{}',
}) =>
    EngineJobs.run(
      EngineAsyncJob.httpGet,
      {
        'url': url,
        'timeout_secs': timeoutSecs,
        'headers_json': headersJson,
      },
    );

Future<String> runHttpPostJson(
  String url, {
  int timeoutSecs = 15,
  String headersJson = '{}',
  String body = '',
}) =>
    EngineJobs.run(
      EngineAsyncJob.httpPost,
      {
        'url': url,
        'timeout_secs': timeoutSecs,
        'headers_json': headersJson,
        'body': body,
      },
    );

Future<String> runAnimeRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.animeRequest,
      {'requestJson': requestJson},
    );

Future<String> runIndexerRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.indexerRequest,
      {'requestJson': requestJson},
    );

Future<String> runDebridRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.debridRequest,
      {'requestJson': requestJson},
    );

Future<String> runSite111477IndexRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.site111477IndexRequest,
      {'requestJson': requestJson},
    );

Future<String> runMegaResolveJson(String embedUrl) => EngineWorkerPool.run(
      EngineJobKind.megaResolve,
      {'embedUrl': embedUrl},
    );

Future<String> runMusicRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.musicRequest,
      {'requestJson': requestJson},
    );

Future<String> runMetadataRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.metadataRequest,
      {'requestJson': requestJson},
    );

Future<String> runSubtitleRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.subtitleRequest,
      {'requestJson': requestJson},
    );

Future<String> runTmdbGetJson(
  String resourcePath, {
  int timeoutSecs = 15,
}) =>
    EngineWorkerPool.run(
      EngineJobKind.tmdbGet,
      {'resourcePath': resourcePath, 'timeoutSecs': timeoutSecs},
    );

Future<String> runTraktRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.traktRequest,
      {'requestJson': requestJson},
    );

Future<String> runAnilistQueryJson(
  String query, {
  String variablesJson = '{}',
}) =>
    EngineWorkerPool.run(
      EngineJobKind.anilistQuery,
      {'query': query, 'variablesJson': variablesJson},
    );

Future<String> runMangaFetchHtml(
  String url, {
  String headersJson = '{}',
  int timeoutSecs = 15,
}) =>
    EngineWorkerPool.run(
      EngineJobKind.mangaFetchHtml,
      {
        'url': url,
        'headersJson': headersJson,
        'timeoutSecs': timeoutSecs,
      },
    );

Future<String> runJellyfinRequestJson(String requestJson) =>
    EngineWorkerPool.run(
      EngineJobKind.jellyfinRequest,
      {'requestJson': requestJson},
    );

Future<String> runIptvProbeStreamJson(String url, {int timeoutSecs = 8}) =>
    EngineJobs.run(
      EngineAsyncJob.iptvProbeStream,
      {'url': url, 'timeout_secs': timeoutSecs},
    );

// ── CPU / fast — worker pool ────────────────────────────────────────────────

Future<String> runOpensslAesDecryptJson(
  String intermediate, {
  String passphrase = '',
}) =>
    EngineWorkerPool.run(
      EngineJobKind.opensslAesDecrypt,
      {'b64': intermediate, 'passphrase': passphrase},
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

Future<String> runDecryptPasteResponse(
  String urlWithHash,
  String rawResponse,
) =>
    EngineWorkerPool.run(
      EngineJobKind.decryptPasteResponse,
      {'urlWithHash': urlWithHash, 'rawResponse': rawResponse},
    );
