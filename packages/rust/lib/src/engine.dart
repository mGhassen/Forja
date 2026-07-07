// FFI symbol names mirror the Rust exports.
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Loads the Rust engine (`libffi`) and exposes typed helpers.
class RustLib {
  RustLib._(this._lib);

  static RustLib? _instance;

  final ffi.DynamicLibrary _lib;
  late final _FfiNative _native = _FfiNative(_lib);

  static RustLib get instance {
    if (_instance == null) {
      throw StateError('Call RustLib.init() before using the engine');
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  /// Path used by the main isolate after [init]. Pass to worker isolates.
  static String? loadedLibraryPath;

  static Future<void> init({String? libraryPath}) async {
    if (_instance != null) return;
    final path = libraryPath ?? _defaultLibraryPath();
    initSync(path);
  }

  /// Clears a partially-loaded library so [init] can try another path.
  static void reset() {
    _instance = null;
    loadedLibraryPath = null;
  }

  /// Opens the dylib synchronously — for worker isolates only.
  static void initSync(String libraryPath) {
    if (_instance != null) return;
    final lib = ffi.DynamicLibrary.open(libraryPath);
    _instance = RustLib._(lib);
    loadedLibraryPath = libraryPath;
  }

  static String _defaultLibraryPath() {
    const name = 'ffi';
    if (Platform.isAndroid) {
      return 'lib$name.so';
    }
    if (Platform.isIOS) {
      return 'lib$name.dylib';
    }
    if (Platform.isMacOS) {
      return 'crates/target/release/lib$name.dylib';
    }
    if (Platform.isLinux) {
      return 'crates/target/release/lib$name.so';
    }
    if (Platform.isWindows) {
      return 'crates/target/release/$name.dll';
    }
    throw UnsupportedError('RustLib FFI is not configured for this platform');
  }

  String get version => _readString(_native.ffi_version());

  void engineCancelPending() => _native.ffi_engine_cancel_pending();

  int engineSubmitJob(int kind, String payloadJson) => using((arena) {
        final ptr = payloadJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _native.ffi_engine_submit_job(kind, ptr);
      });

  String? engineTakeJobResult(int jobId) {
    final ptr = _native.ffi_engine_take_job_result(jobId);
    if (ptr == ffi.nullptr) return null;
    return _readString(ptr);
  }

  int add(int a, int b) => _native.ffi_add(a, b);

  bool episodeMatches(String filename, int season, int episode) {
    return using((arena) {
      final ptr = filename.toNativeUtf8(allocator: arena).cast<ffi.Char>();
      return _native.ffi_episode_matches(ptr, season, episode);
    });
  }

  int pickEpisodeIndexJson(String filesJson, int season, int episode) {
    return using((arena) {
      final ptr = filesJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
      return _native.ffi_pick_episode_index_json(ptr, season, episode);
    });
  }

  int pickLargestVideoIndexJson(String filesJson) {
    return using((arena) {
      final ptr = filesJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
      return _native.ffi_pick_largest_video_index_json(ptr);
    });
  }

  String normalizeTorrentTitle(String title) => using((arena) {
        final ptr = title.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_normalize_torrent_title(ptr));
      });

  String unpackJs(String source) => using((arena) {
        final ptr = source.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_unpack_js(ptr));
      });

  String buildMovieUrl(String providerId, int tmdbId) => using((arena) {
        final ptr = providerId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_build_movie_url(ptr, tmdbId));
      });

  String buildTvUrl(String providerId, int tmdbId, int season, int episode) =>
      using((arena) {
        final ptr = providerId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_build_tv_url(ptr, tmdbId, season, episode),
        );
      });

  String listProvidersJson() =>
      _readString(_native.ffi_list_providers_json());

  String parseM3uJson(String content) => using((arena) {
        final ptr = content.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_m3u_json(ptr));
      });

  String decryptPasteResponse(String urlWithHash, String rawResponse) =>
      using((arena) {
        final urlPtr = urlWithHash.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final rawPtr = rawResponse.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_decrypt_paste_response(urlPtr, rawPtr));
      });

  String opensslAesDecryptJson(String b64, {String passphrase = ''}) =>
      using((arena) {
        final b64Ptr = b64.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final passPtr =
            passphrase.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_openssl_aes_decrypt_json(b64Ptr, passPtr),
        );
      });

  String decodeXtreamText(String text) => using((arena) {
        final ptr = text.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_decode_xtream_text(ptr));
      });

  String parseXtreamCategoriesJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_xtream_categories_json(ptr));
      });

  String parseXtreamStreamsJson(String json, String section) => using((arena) {
        final jsonPtr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final sectionPtr =
            section.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_parse_xtream_streams_json(jsonPtr, sectionPtr),
        );
      });

  String parseXtreamSeriesEpisodesJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_xtream_series_episodes_json(ptr));
      });

  String parseSceneInfoJson(String title) => using((arena) {
        final ptr = title.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_scene_info_json(ptr));
      });

  String parseHlsMasterJson(String masterUrl, String body) => using((arena) {
        final urlPtr = masterUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final bodyPtr = body.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_parse_hls_master_json(urlPtr, bodyPtr),
        );
      });

  String decryptKisskhBody(String body, {String? sourceUrl}) => using((arena) {
        final bodyPtr = body.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final sourcePtr = sourceUrl == null
            ? ffi.nullptr
            : sourceUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_decrypt_kisskh_body(bodyPtr, sourcePtr),
        );
      });

  String buildStremioResourceUrl(String addonUrl, String resourcePath) =>
      using((arena) {
        final a = addonUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final r = resourcePath.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_build_stremio_resource_url(a, r));
      });

  String normalizeStremioManifestUrl(String url) => using((arena) {
        final ptr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_normalize_stremio_manifest_url(ptr));
      });

  String splitStremioAddonUrlJson(String url) => using((arena) {
        final ptr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_split_stremio_addon_url_json(ptr));
      });

  String parseStremioManifestJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_stremio_manifest_json(ptr));
      });

  String parseStremioStreamsJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_stremio_streams_json(ptr));
      });

  String parseStremioSubtitlesJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_stremio_subtitles_json(ptr));
      });

  String parseStremioCatalogJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_stremio_catalog_json(ptr));
      });

  String parseStremioMetaJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_stremio_meta_json(ptr));
      });

  String stremioHttpGet(String url, {int timeoutSecs = 15}) => using((arena) {
        final ptr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_stremio_http_get_json(ptr, timeoutSecs),
        );
      });

  String httpGetJson(
    String url, {
    int timeoutSecs = 15,
    String headersJson = '{}',
  }) =>
      using((arena) {
        final urlPtr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final hdrPtr =
            headersJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_http_get_json(urlPtr, timeoutSecs, hdrPtr),
        );
      });

  String httpPostJson(
    String url, {
    int timeoutSecs = 15,
    String headersJson = '{}',
    String body = '',
  }) =>
      using((arena) {
        final urlPtr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final hdrPtr =
            headersJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final bodyPtr = body.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_http_post_json(urlPtr, timeoutSecs, hdrPtr, bodyPtr),
        );
      });

  String iptvProbeStreamJson(String url, {int timeoutSecs = 8}) => using((arena) {
        final urlPtr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_iptv_probe_stream_json(urlPtr, timeoutSecs),
        );
      });

  String tmdbGetJson(String resourcePath, {int timeoutSecs = 15}) =>
      using((arena) {
        final ptr =
            resourcePath.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_tmdb_get_json(ptr, timeoutSecs));
      });

  String traktRequestJson(String requestJson) => using((arena) {
        final ptr = requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_trakt_request_json(ptr));
      });

  String jellyfinRequestJson(String requestJson) => using((arena) {
        final ptr = requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_jellyfin_request_json(ptr));
      });

  String anilistQueryJson(
    String query, {
    String variablesJson = '{}',
  }) =>
      using((arena) {
        final qPtr = query.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final vPtr =
            variablesJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_anilist_query_json(qPtr, vPtr));
      });

  String mangaFetchHtml(
    String url, {
    String headersJson = '{}',
    int timeoutSecs = 15,
  }) =>
      using((arena) {
        final urlPtr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final hdrPtr =
            headersJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_manga_fetch_html(urlPtr, hdrPtr, timeoutSecs),
        );
      });

  String animeRequestJson(String requestJson) => using((arena) {
        final ptr = requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_anime_request_json(ptr));
      });

  String indexerRequestJson(String requestJson) => using((arena) {
        final ptr = requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_indexer_request_json(ptr));
      });

  String debridRequestJson(String requestJson) => using((arena) {
        final ptr = requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_debrid_request_json(ptr));
      });

  String site111477IndexRequestJson(String requestJson) => using((arena) {
        final ptr = requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_site111477_index_request_json(ptr));
      });

  String megaResolveJson(String embedUrl) => using((arena) {
        final ptr = embedUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_mega_resolve_json(ptr));
      });

  String parseKnabenHtmlJson(String html) => using((arena) {
        final ptr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_knaben_html_json(ptr));
      });

  String parseTpbHtmlJson(String html) => using((arena) {
        final ptr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_tpb_html_json(ptr));
      });

  String parseUindexHtmlJson(String html) => using((arena) {
        final ptr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_uindex_html_json(ptr));
      });

  String dedupTorrentsJson(String resultsJson) => using((arena) {
        final ptr = resultsJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_dedup_torrents_json(ptr));
      });

  String searchTorrentsJson(String query) => using((arena) {
        final ptr = query.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_search_torrents_json(ptr));
      });

  String filterTorrentsJson(
    String resultsJson,
    String showTitle, {
    int requiredSeason = -1,
    int requiredEpisode = -1,
  }) =>
      using((arena) {
        final resultsPtr =
            resultsJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final titlePtr =
            showTitle.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_filter_torrents_json(
            resultsPtr,
            titlePtr,
            requiredSeason,
            requiredEpisode,
          ),
        );
      });

  String sortTorrentsJson(String resultsJson, String preference) =>
      using((arena) {
        final resultsPtr =
            resultsJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final prefPtr =
            preference.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_sort_torrents_json(resultsPtr, prefPtr),
        );
      });

  bool isVideoFile(String fileName) => using((arena) {
        final ptr = fileName.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _native.ffi_is_video_file(ptr);
      });

  String extractEmbedHtmlJson(
    String extractorId,
    String html,
    String pageUrl,
  ) =>
      using((arena) {
        final idPtr =
            extractorId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final urlPtr = pageUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_extract_embed_html_json(idPtr, htmlPtr, urlPtr),
        );
      });

  String extractVidsrcChainJson(
    String outerHtml,
    String rcpHtml,
    String prorcpHtml,
  ) =>
      using((arena) {
        final a = outerHtml.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final b = rcpHtml.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final c = prorcpHtml.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_extract_vidsrc_chain_json(a, b, c));
      });

  String resolveVidsrcEmbedJson(String requestJson) => using((arena) {
        final reqPtr =
            requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_resolve_vidsrc_embed_json(reqPtr));
      });

  String extractHubcloudLinksJson(String html, String pageUrl) => using((arena) {
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final urlPtr = pageUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_extract_hubcloud_links_json(htmlPtr, urlPtr));
      });

  String extractMfpEmbedHtmlJson(
    String extractorId,
    String html,
    String pageUrl,
    String mfpConfigJson, {
    String extraHtml = '',
  }) =>
      using((arena) {
        final idPtr =
            extractorId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final urlPtr = pageUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final mfpPtr =
            mfpConfigJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final extraPtr = extraHtml.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_extract_mfp_embed_html_json(
          idPtr,
          htmlPtr,
          urlPtr,
          mfpPtr,
          extraPtr,
        ));
      });

  String resolveWebstreamrSourceJson(String sourceId, String requestJson) =>
      using((arena) {
        final idPtr = sourceId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final reqPtr =
            requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_resolve_webstreamr_source_json(idPtr, reqPtr),
        );
      });

  String webstreamrGetStreamsJson(String requestJson) => using((arena) {
        final reqPtr =
            requestJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_webstreamr_get_streams_json(reqPtr));
      });

  String extractKinogerEpisodeUrlsJson(
    String html,
    int seasonIndex,
    int episodeIndex,
  ) =>
      using((arena) {
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_extract_kinoger_episode_urls_json(
          htmlPtr,
          seasonIndex,
          episodeIndex,
        ));
      });

  String parseWebstreamrSourceHtmlJson(
    String sourceId,
    String html,
    String optsJson,
  ) =>
      using((arena) {
        final idPtr = sourceId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final optsPtr = optsJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_parse_webstreamr_source_html_json(
          idPtr,
          htmlPtr,
          optsPtr,
        ));
      });

  bool torrentStart(String magnet) => using((arena) {
        final ptr = magnet.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _native.ffi_torrent_start(ptr);
      });

  void torrentStop() => _native.ffi_torrent_stop();

  bool torrentIsRunning() => _native.ffi_torrent_is_running();

  String torrentStatusJson() =>
      _readString(_native.ffi_torrent_status_json());

  int torrentEngineStart(int preferredPort) =>
      _native.ffi_torrent_engine_start(preferredPort);

  String torrentEngineLastError() =>
      _readString(_native.ffi_torrent_engine_last_error());

  int torrentEnginePort() => _native.ffi_torrent_engine_port();

  void torrentEngineStop() => _native.ffi_torrent_engine_stop();

  void torrentSetPeerLimit(int limit) =>
      _native.ffi_torrent_set_peer_limit(limit);

  String torrentStreamJson(
    String magnet, {
    int? season,
    int? episode,
    int? fileIdx,
  }) =>
      using((arena) {
        final ptr = magnet.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.ffi_torrent_stream_json(
            ptr,
            season ?? -1,
            episode ?? -1,
            fileIdx ?? -1,
          ),
        );
      });

  String torrentListFilesJson(String magnet) => using((arena) {
        final ptr = magnet.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_torrent_list_files_json(ptr));
      });

  int proxyStart(int preferredPort) => _native.ffi_proxy_start(preferredPort);

  void proxyStop() => _native.ffi_proxy_stop();

  int proxyPort() => _native.ffi_proxy_port();

  bool proxyRegisterRoute(String token, String upstreamUrl) => using((arena) {
        final tokenPtr = token.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final urlPtr = upstreamUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _native.ffi_proxy_register_route(tokenPtr, urlPtr);
      });

  String seek111477StartJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_seek111477_start_json(ptr));
      });

  void seek111477Stop() => _native.ffi_seek111477_stop();

  int seek111477Port() => _native.ffi_seek111477_port();

  bool seek111477IsRunning() => _native.ffi_seek111477_is_running();

  String seek111477PurgeCacheJson(String cacheDir) => using((arena) {
        final ptr = cacheDir.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_seek111477_purge_cache_json(ptr));
      });

  String storageOpen(String path) => using((arena) {
        final ptr = path.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_storage_open(ptr));
      });

  String storageGetJson(String key) => using((arena) {
        final ptr = key.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_storage_get_json(ptr));
      });

  String storageSetJson(String key, String valueJson) => using((arena) {
        final keyPtr = key.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final valPtr = valueJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.ffi_storage_set_json(keyPtr, valPtr));
      });

  String _readString(ffi.Pointer<ffi.Char> ptr) {
    if (ptr == ffi.nullptr) return '';
    try {
      return ptr.cast<Utf8>().toDartString();
    } finally {
      _native.ffi_free_string(ptr);
    }
  }
}

final class _FfiNative {
  _FfiNative(ffi.DynamicLibrary lib)
      : ffi_free_string = lib
            .lookup<ffi.NativeFunction<_FreeStringNative>>('ffi_free_string')
            .asFunction(),
        ffi_version = lib
            .lookup<ffi.NativeFunction<_VersionNative>>('ffi_version')
            .asFunction(),
        ffi_engine_cancel_pending = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>(
              'ffi_engine_cancel_pending',
            )
            .asFunction(),
        ffi_engine_submit_job = lib
            .lookup<ffi.NativeFunction<_EngineSubmitJobNative>>(
              'ffi_engine_submit_job',
            )
            .asFunction(),
        ffi_engine_take_job_result = lib
            .lookup<ffi.NativeFunction<_EngineTakeJobNative>>(
              'ffi_engine_take_job_result',
            )
            .asFunction(),
        ffi_add =
            lib.lookup<ffi.NativeFunction<_AddNative>>('ffi_add').asFunction(),
        ffi_episode_matches = lib
            .lookup<ffi.NativeFunction<_EpisodeMatchesNative>>(
              'ffi_episode_matches',
            )
            .asFunction(),
        ffi_pick_episode_index_json = lib
            .lookup<ffi.NativeFunction<_PickEpisodeIndexNative>>(
              'ffi_pick_episode_index_json',
            )
            .asFunction(),
        ffi_pick_largest_video_index_json = lib
            .lookup<ffi.NativeFunction<_PickLargestVideoIndexNative>>(
              'ffi_pick_largest_video_index_json',
            )
            .asFunction(),
        ffi_normalize_torrent_title = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_normalize_torrent_title',
            )
            .asFunction(),
        ffi_unpack_js = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>('ffi_unpack_js')
            .asFunction(),
        ffi_build_movie_url = lib
            .lookup<ffi.NativeFunction<_BuildMovieUrlNative>>(
              'ffi_build_movie_url',
            )
            .asFunction(),
        ffi_build_tv_url = lib
            .lookup<ffi.NativeFunction<_BuildTvUrlNative>>('ffi_build_tv_url')
            .asFunction(),
        ffi_list_providers_json = lib
            .lookup<ffi.NativeFunction<_VersionNative>>(
              'ffi_list_providers_json',
            )
            .asFunction(),
        ffi_parse_m3u_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_m3u_json',
            )
            .asFunction(),
        ffi_decrypt_paste_response = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_decrypt_paste_response',
            )
            .asFunction(),
        ffi_openssl_aes_decrypt_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_openssl_aes_decrypt_json',
            )
            .asFunction(),
        ffi_decode_xtream_text = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_decode_xtream_text',
            )
            .asFunction(),
        ffi_parse_xtream_categories_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_xtream_categories_json',
            )
            .asFunction(),
        ffi_parse_xtream_streams_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_parse_xtream_streams_json',
            )
            .asFunction(),
        ffi_parse_xtream_series_episodes_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_xtream_series_episodes_json',
            )
            .asFunction(),
        ffi_parse_scene_info_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_scene_info_json',
            )
            .asFunction(),
        ffi_parse_hls_master_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_parse_hls_master_json',
            )
            .asFunction(),
        ffi_decrypt_kisskh_body = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_decrypt_kisskh_body',
            )
            .asFunction(),
        ffi_build_stremio_resource_url = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_build_stremio_resource_url',
            )
            .asFunction(),
        ffi_normalize_stremio_manifest_url = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_normalize_stremio_manifest_url',
            )
            .asFunction(),
        ffi_split_stremio_addon_url_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_split_stremio_addon_url_json',
            )
            .asFunction(),
        ffi_parse_stremio_manifest_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_stremio_manifest_json',
            )
            .asFunction(),
        ffi_parse_stremio_streams_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_stremio_streams_json',
            )
            .asFunction(),
        ffi_parse_stremio_subtitles_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_stremio_subtitles_json',
            )
            .asFunction(),
        ffi_parse_stremio_catalog_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_stremio_catalog_json',
            )
            .asFunction(),
        ffi_parse_stremio_meta_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_stremio_meta_json',
            )
            .asFunction(),
        ffi_stremio_http_get_json = lib
            .lookup<ffi.NativeFunction<_StremioHttpGetNative>>(
              'ffi_stremio_http_get_json',
            )
            .asFunction(),
        ffi_http_get_json = lib
            .lookup<ffi.NativeFunction<_HttpGetNative>>(
              'ffi_http_get_json',
            )
            .asFunction(),
        ffi_http_post_json = lib
            .lookup<ffi.NativeFunction<_HttpPostNative>>(
              'ffi_http_post_json',
            )
            .asFunction(),
        ffi_iptv_probe_stream_json = lib
            .lookup<ffi.NativeFunction<_StremioHttpGetNative>>(
              'ffi_iptv_probe_stream_json',
            )
            .asFunction(),
        ffi_tmdb_get_json = lib
            .lookup<ffi.NativeFunction<_StremioHttpGetNative>>(
              'ffi_tmdb_get_json',
            )
            .asFunction(),
        ffi_trakt_request_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_trakt_request_json',
            )
            .asFunction(),
        ffi_jellyfin_request_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_jellyfin_request_json',
            )
            .asFunction(),
        ffi_anilist_query_json = lib
            .lookup<ffi.NativeFunction<_AnilistQueryNative>>(
              'ffi_anilist_query_json',
            )
            .asFunction(),
        ffi_manga_fetch_html = lib
            .lookup<ffi.NativeFunction<_MangaFetchNative>>(
              'ffi_manga_fetch_html',
            )
            .asFunction(),
        ffi_anime_request_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_anime_request_json',
            )
            .asFunction(),
        ffi_indexer_request_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_indexer_request_json',
            )
            .asFunction(),
        ffi_debrid_request_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_debrid_request_json',
            )
            .asFunction(),
        ffi_site111477_index_request_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_site111477_index_request_json',
            )
            .asFunction(),
        ffi_mega_resolve_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_mega_resolve_json',
            )
            .asFunction(),
        ffi_parse_knaben_html_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_knaben_html_json',
            )
            .asFunction(),
        ffi_parse_tpb_html_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_tpb_html_json',
            )
            .asFunction(),
        ffi_parse_uindex_html_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_parse_uindex_html_json',
            )
            .asFunction(),
        ffi_dedup_torrents_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_dedup_torrents_json',
            )
            .asFunction(),
        ffi_search_torrents_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_search_torrents_json',
            )
            .asFunction(),
        ffi_filter_torrents_json = lib
            .lookup<ffi.NativeFunction<_FilterTorrentsNative>>(
              'ffi_filter_torrents_json',
            )
            .asFunction(),
        ffi_sort_torrents_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_sort_torrents_json',
            )
            .asFunction(),
        ffi_is_video_file = lib
            .lookup<ffi.NativeFunction<_StringBoolNative>>(
              'ffi_is_video_file',
            )
            .asFunction(),
        ffi_extract_embed_html_json = lib
            .lookup<ffi.NativeFunction<_ThreeStringNative>>(
              'ffi_extract_embed_html_json',
            )
            .asFunction(),
        ffi_extract_vidsrc_chain_json = lib
            .lookup<ffi.NativeFunction<_ThreeStringNative>>(
              'ffi_extract_vidsrc_chain_json',
            )
            .asFunction(),
        ffi_resolve_vidsrc_embed_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_resolve_vidsrc_embed_json',
            )
            .asFunction(),
        ffi_extract_hubcloud_links_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_extract_hubcloud_links_json',
            )
            .asFunction(),
        ffi_extract_mfp_embed_html_json = lib
            .lookup<ffi.NativeFunction<_FiveStringNative>>(
              'ffi_extract_mfp_embed_html_json',
            )
            .asFunction(),
        ffi_resolve_webstreamr_source_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'ffi_resolve_webstreamr_source_json',
            )
            .asFunction(),
        ffi_webstreamr_get_streams_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'ffi_webstreamr_get_streams_json',
            )
            .asFunction(),
        ffi_extract_kinoger_episode_urls_json = lib
            .lookup<ffi.NativeFunction<_KinogerUrlsNative>>(
              'ffi_extract_kinoger_episode_urls_json',
            )
            .asFunction(),
        ffi_parse_webstreamr_source_html_json = lib
            .lookup<ffi.NativeFunction<_ThreeStringNative>>(
              'ffi_parse_webstreamr_source_html_json',
            )
            .asFunction(),
        ffi_torrent_start = lib
            .lookup<ffi.NativeFunction<_TorrentStartNative>>(
              'ffi_torrent_start',
            )
            .asFunction(),
        ffi_torrent_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>('ffi_torrent_stop')
            .asFunction(),
        ffi_torrent_is_running = lib
            .lookup<ffi.NativeFunction<_TorrentIsRunningNative>>(
              'ffi_torrent_is_running',
            )
            .asFunction(),
        ffi_torrent_status_json = lib
            .lookup<ffi.NativeFunction<_VersionNative>>(
              'ffi_torrent_status_json',
            )
            .asFunction(),
        ffi_torrent_engine_start = lib
            .lookup<ffi.NativeFunction<_ProxyStartNative>>(
              'ffi_torrent_engine_start',
            )
            .asFunction(),
        ffi_torrent_engine_last_error = lib
            .lookup<ffi.NativeFunction<_VersionNative>>(
              'ffi_torrent_engine_last_error',
            )
            .asFunction(),
        ffi_torrent_engine_port = lib
            .lookup<ffi.NativeFunction<_ProxyPortNative>>(
              'ffi_torrent_engine_port',
            )
            .asFunction(),
        ffi_torrent_engine_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>(
              'ffi_torrent_engine_stop',
            )
            .asFunction(),
        ffi_torrent_set_peer_limit = lib
            .lookup<ffi.NativeFunction<_TorrentSetPeerLimitNative>>(
              'ffi_torrent_set_peer_limit',
            )
            .asFunction(),
        ffi_torrent_stream_json = lib
            .lookup<ffi.NativeFunction<_TorrentStreamJsonNative>>(
              'ffi_torrent_stream_json',
            )
            .asFunction(),
        ffi_torrent_list_files_json = lib
            .lookup<ffi.NativeFunction<_TorrentJsonNative>>(
              'ffi_torrent_list_files_json',
            )
            .asFunction(),
        ffi_proxy_start = lib
            .lookup<ffi.NativeFunction<_ProxyStartNative>>('ffi_proxy_start')
            .asFunction(),
        ffi_proxy_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>('ffi_proxy_stop')
            .asFunction(),
        ffi_proxy_port = lib
            .lookup<ffi.NativeFunction<_ProxyPortNative>>('ffi_proxy_port')
            .asFunction(),
        ffi_proxy_register_route = lib
            .lookup<ffi.NativeFunction<_ProxyRegisterNative>>(
              'ffi_proxy_register_route',
            )
            .asFunction(),
        ffi_seek111477_start_json = lib
            .lookup<ffi.NativeFunction<_Seek111477JsonNative>>(
              'ffi_seek111477_start_json',
            )
            .asFunction(),
        ffi_seek111477_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>(
              'ffi_seek111477_stop',
            )
            .asFunction(),
        ffi_seek111477_port = lib
            .lookup<ffi.NativeFunction<_Seek111477PortNative>>(
              'ffi_seek111477_port',
            )
            .asFunction(),
        ffi_seek111477_is_running = lib
            .lookup<ffi.NativeFunction<_Seek111477IsRunningNative>>(
              'ffi_seek111477_is_running',
            )
            .asFunction(),
        ffi_seek111477_purge_cache_json = lib
            .lookup<ffi.NativeFunction<_Seek111477JsonNative>>(
              'ffi_seek111477_purge_cache_json',
            )
            .asFunction(),
        ffi_storage_open = lib
            .lookup<ffi.NativeFunction<_StoragePathNative>>('ffi_storage_open')
            .asFunction(),
        ffi_storage_get_json = lib
            .lookup<ffi.NativeFunction<_StorageKeyNative>>(
              'ffi_storage_get_json',
            )
            .asFunction(),
        ffi_storage_set_json = lib
            .lookup<ffi.NativeFunction<_StorageSetNative>>(
              'ffi_storage_set_json',
            )
            .asFunction();

  final void Function(ffi.Pointer<ffi.Char>) ffi_free_string;
  final ffi.Pointer<ffi.Char> Function() ffi_version;
  final void Function() ffi_engine_cancel_pending;
  final int Function(int, ffi.Pointer<ffi.Char>) ffi_engine_submit_job;
  final ffi.Pointer<ffi.Char> Function(int) ffi_engine_take_job_result;
  final int Function(int, int) ffi_add;
  final bool Function(ffi.Pointer<ffi.Char>, int, int) ffi_episode_matches;
  final int Function(ffi.Pointer<ffi.Char>, int, int)
      ffi_pick_episode_index_json;
  final int Function(ffi.Pointer<ffi.Char>)
      ffi_pick_largest_video_index_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_normalize_torrent_title;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) ffi_unpack_js;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, int)
      ffi_build_movie_url;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    int,
    int,
  ) ffi_build_tv_url;
  final ffi.Pointer<ffi.Char> Function() ffi_list_providers_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_m3u_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_decrypt_paste_response;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_openssl_aes_decrypt_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_decode_xtream_text;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_xtream_categories_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_parse_xtream_streams_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_xtream_series_episodes_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_scene_info_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_parse_hls_master_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_decrypt_kisskh_body;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_build_stremio_resource_url;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_normalize_stremio_manifest_url;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_split_stremio_addon_url_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_stremio_manifest_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_stremio_streams_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_stremio_subtitles_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_stremio_catalog_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_stremio_meta_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, int)
      ffi_stremio_http_get_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    ffi.Pointer<ffi.Char>,
  ) ffi_http_get_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_http_post_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, int)
      ffi_iptv_probe_stream_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, int)
      ffi_tmdb_get_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_trakt_request_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_jellyfin_request_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_anilist_query_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
  ) ffi_manga_fetch_html;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_anime_request_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_indexer_request_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_debrid_request_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_site111477_index_request_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_mega_resolve_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_knaben_html_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_tpb_html_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_parse_uindex_html_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_dedup_torrents_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_search_torrents_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
    int,
  ) ffi_filter_torrents_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_sort_torrents_json;
  final bool Function(ffi.Pointer<ffi.Char>) ffi_is_video_file;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_extract_embed_html_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_extract_vidsrc_chain_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_resolve_vidsrc_embed_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_extract_hubcloud_links_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_extract_mfp_embed_html_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_resolve_webstreamr_source_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_webstreamr_get_streams_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    int,
  ) ffi_extract_kinoger_episode_urls_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_parse_webstreamr_source_html_json;
  final bool Function(ffi.Pointer<ffi.Char>) ffi_torrent_start;
  final void Function() ffi_torrent_stop;
  final bool Function() ffi_torrent_is_running;
  final ffi.Pointer<ffi.Char> Function() ffi_torrent_status_json;
  final int Function(int) ffi_torrent_engine_start;
  final ffi.Pointer<ffi.Char> Function() ffi_torrent_engine_last_error;
  final int Function() ffi_torrent_engine_port;
  final void Function() ffi_torrent_engine_stop;
  final void Function(int) ffi_torrent_set_peer_limit;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    int,
    int,
  ) ffi_torrent_stream_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_torrent_list_files_json;
  final int Function(int) ffi_proxy_start;
  final void Function() ffi_proxy_stop;
  final int Function() ffi_proxy_port;
  final bool Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_proxy_register_route;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_seek111477_start_json;
  final void Function() ffi_seek111477_stop;
  final int Function() ffi_seek111477_port;
  final bool Function() ffi_seek111477_is_running;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_seek111477_purge_cache_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) ffi_storage_open;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      ffi_storage_get_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) ffi_storage_set_json;
}

typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<ffi.Char>);
typedef _VersionNative = ffi.Pointer<ffi.Char> Function();
typedef _AddNative = ffi.Int64 Function(ffi.Int64, ffi.Int64);
typedef _EpisodeMatchesNative = ffi.Bool Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
);
typedef _PickEpisodeIndexNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
);
typedef _PickLargestVideoIndexNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char>,
);
typedef _FilterTorrentsNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
);
typedef _StringInOutNative =
    ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);
typedef _StremioHttpGetNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Uint64,
);
typedef _AnilistQueryNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
typedef _MangaFetchNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Int,
);
typedef _HttpGetNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Uint64,
  ffi.Pointer<ffi.Char>,
);
typedef _HttpPostNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Uint64,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
typedef _BuildMovieUrlNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int64,
);
typedef _BuildTvUrlNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int64,
  ffi.Int32,
  ffi.Int32,
);
typedef _TwoStringNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
typedef _ThreeStringNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
typedef _FiveStringNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
typedef _KinogerUrlsNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
);
typedef _StringBoolNative = ffi.Bool Function(ffi.Pointer<ffi.Char>);
typedef _TorrentStartNative = ffi.Bool Function(ffi.Pointer<ffi.Char>);
typedef _TorrentStopNative = ffi.Void Function();
typedef _EngineSubmitJobNative = ffi.Uint64 Function(
  ffi.Uint32,
  ffi.Pointer<ffi.Char>,
);
typedef _EngineTakeJobNative =
    ffi.Pointer<ffi.Char> Function(ffi.Uint64);
typedef _TorrentSetPeerLimitNative = ffi.Void Function(ffi.Uint32);
typedef _TorrentIsRunningNative = ffi.Bool Function();
typedef _TorrentStreamJsonNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
  ffi.Int32,
);
typedef _TorrentJsonNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
);
typedef _ProxyStartNative = ffi.Int32 Function(ffi.Uint16);
typedef _ProxyPortNative = ffi.Uint16 Function();
typedef _ProxyRegisterNative = ffi.Bool Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
typedef _Seek111477JsonNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
);
typedef _Seek111477PortNative = ffi.Uint32 Function();
typedef _Seek111477IsRunningNative = ffi.Bool Function();
typedef _StoragePathNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
);
typedef _StorageKeyNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
);
typedef _StorageSetNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
);
