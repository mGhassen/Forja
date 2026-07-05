import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Loads the Forja Rust engine (`libffi`) and exposes typed helpers.
class ForjaRust {
  ForjaRust._(this._lib);

  static ForjaRust? _instance;

  final ffi.DynamicLibrary _lib;
  late final _ForjaNative _native = _ForjaNative(_lib);

  static ForjaRust get instance {
    if (_instance == null) {
      throw StateError('Call ForjaRust.init() before using the engine');
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static Future<void> init({String? libraryPath}) async {
    if (_instance != null) return;
    final path = libraryPath ?? _defaultLibraryPath();
    final lib = ffi.DynamicLibrary.open(path);
    _instance = ForjaRust._(lib);
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
    throw UnsupportedError('ForjaRust FFI is not configured for this platform');
  }

  String get version => _readString(_native.forja_version());

  int add(int a, int b) => _native.forja_add(a, b);

  bool episodeMatches(String filename, int season, int episode) {
    return using((arena) {
      final ptr = filename.toNativeUtf8(allocator: arena).cast<ffi.Char>();
      return _native.forja_episode_matches(ptr, season, episode);
    });
  }

  String normalizeTorrentTitle(String title) => using((arena) {
        final ptr = title.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_normalize_torrent_title(ptr));
      });

  String unpackJs(String source) => using((arena) {
        final ptr = source.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_unpack_js(ptr));
      });

  String buildMovieUrl(String providerId, int tmdbId) => using((arena) {
        final ptr = providerId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_build_movie_url(ptr, tmdbId));
      });

  String buildTvUrl(String providerId, int tmdbId, int season, int episode) =>
      using((arena) {
        final ptr = providerId.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.forja_build_tv_url(ptr, tmdbId, season, episode),
        );
      });

  String listProvidersJson() =>
      _readString(_native.forja_list_providers_json());

  String parseM3uJson(String content) => using((arena) {
        final ptr = content.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_m3u_json(ptr));
      });

  String decryptPasteResponse(String urlWithHash, String rawResponse) =>
      using((arena) {
        final urlPtr = urlWithHash.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final rawPtr = rawResponse.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_decrypt_paste_response(urlPtr, rawPtr));
      });

  String decodeXtreamText(String text) => using((arena) {
        final ptr = text.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_decode_xtream_text(ptr));
      });

  String parseXtreamCategoriesJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_xtream_categories_json(ptr));
      });

  String parseXtreamStreamsJson(String json, String section) => using((arena) {
        final jsonPtr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final sectionPtr =
            section.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.forja_parse_xtream_streams_json(jsonPtr, sectionPtr),
        );
      });

  String parseXtreamSeriesEpisodesJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_xtream_series_episodes_json(ptr));
      });

  String parseSceneInfoJson(String title) => using((arena) {
        final ptr = title.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_scene_info_json(ptr));
      });

  String parseHlsMasterJson(String masterUrl, String body) => using((arena) {
        final urlPtr = masterUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final bodyPtr = body.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.forja_parse_hls_master_json(urlPtr, bodyPtr),
        );
      });

  String decryptKisskhBody(String body, {String? sourceUrl}) => using((arena) {
        final bodyPtr = body.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final sourcePtr = sourceUrl == null
            ? ffi.nullptr
            : sourceUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.forja_decrypt_kisskh_body(bodyPtr, sourcePtr),
        );
      });

  String buildStremioResourceUrl(String addonUrl, String resourcePath) =>
      using((arena) {
        final a = addonUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final r = resourcePath.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_build_stremio_resource_url(a, r));
      });

  String normalizeStremioManifestUrl(String url) => using((arena) {
        final ptr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_normalize_stremio_manifest_url(ptr));
      });

  String splitStremioAddonUrlJson(String url) => using((arena) {
        final ptr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_split_stremio_addon_url_json(ptr));
      });

  String parseStremioManifestJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_stremio_manifest_json(ptr));
      });

  String parseStremioStreamsJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_stremio_streams_json(ptr));
      });

  String parseStremioSubtitlesJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_stremio_subtitles_json(ptr));
      });

  String parseStremioCatalogJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_stremio_catalog_json(ptr));
      });

  String parseStremioMetaJson(String json) => using((arena) {
        final ptr = json.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_stremio_meta_json(ptr));
      });

  String stremioHttpGet(String url, {int timeoutSecs = 15}) => using((arena) {
        final ptr = url.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.forja_stremio_http_get_json(ptr, timeoutSecs),
        );
      });

  String parseKnabenHtmlJson(String html) => using((arena) {
        final ptr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_knaben_html_json(ptr));
      });

  String parseTpbHtmlJson(String html) => using((arena) {
        final ptr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_tpb_html_json(ptr));
      });

  String parseUindexHtmlJson(String html) => using((arena) {
        final ptr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_parse_uindex_html_json(ptr));
      });

  String dedupTorrentsJson(String resultsJson) => using((arena) {
        final ptr = resultsJson.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_dedup_torrents_json(ptr));
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
          _native.forja_extract_embed_html_json(idPtr, htmlPtr, urlPtr),
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
        return _readString(_native.forja_extract_vidsrc_chain_json(a, b, c));
      });

  String extractHubcloudLinksJson(String html, String pageUrl) => using((arena) {
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final urlPtr = pageUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_extract_hubcloud_links_json(htmlPtr, urlPtr));
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
        return _readString(_native.forja_extract_mfp_embed_html_json(
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
          _native.forja_resolve_webstreamr_source_json(idPtr, reqPtr),
        );
      });

  String extractKinogerEpisodeUrlsJson(
    String html,
    int seasonIndex,
    int episodeIndex,
  ) =>
      using((arena) {
        final htmlPtr = html.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_extract_kinoger_episode_urls_json(
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
        return _readString(_native.forja_parse_webstreamr_source_html_json(
          idPtr,
          htmlPtr,
          optsPtr,
        ));
      });

  bool torrentStart(String magnet) => using((arena) {
        final ptr = magnet.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _native.forja_torrent_start(ptr);
      });

  void torrentStop() => _native.forja_torrent_stop();

  bool torrentIsRunning() => _native.forja_torrent_is_running();

  String torrentStatusJson() =>
      _readString(_native.forja_torrent_status_json());

  int torrentEngineStart(int preferredPort) =>
      _native.forja_torrent_engine_start(preferredPort);

  int torrentEnginePort() => _native.forja_torrent_engine_port();

  void torrentEngineStop() => _native.forja_torrent_engine_stop();

  String torrentStreamJson(
    String magnet, {
    int? season,
    int? episode,
    int? fileIdx,
  }) =>
      using((arena) {
        final ptr = magnet.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(
          _native.forja_torrent_stream_json(
            ptr,
            season ?? -1,
            episode ?? -1,
            fileIdx ?? -1,
          ),
        );
      });

  String torrentListFilesJson(String magnet) => using((arena) {
        final ptr = magnet.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _readString(_native.forja_torrent_list_files_json(ptr));
      });

  int proxyStart(int preferredPort) => _native.forja_proxy_start(preferredPort);

  void proxyStop() => _native.forja_proxy_stop();

  int proxyPort() => _native.forja_proxy_port();

  bool proxyRegisterRoute(String token, String upstreamUrl) => using((arena) {
        final tokenPtr = token.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final urlPtr = upstreamUrl.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        return _native.forja_proxy_register_route(tokenPtr, urlPtr);
      });

  String _readString(ffi.Pointer<ffi.Char> ptr) {
    if (ptr == ffi.nullptr) return '';
    try {
      return ptr.cast<Utf8>().toDartString();
    } finally {
      _native.forja_free_string(ptr);
    }
  }
}

final class _ForjaNative {
  _ForjaNative(ffi.DynamicLibrary lib)
      : forja_free_string = lib
            .lookup<ffi.NativeFunction<_FreeStringNative>>('forja_free_string')
            .asFunction(),
        forja_version = lib
            .lookup<ffi.NativeFunction<_VersionNative>>('forja_version')
            .asFunction(),
        forja_add =
            lib.lookup<ffi.NativeFunction<_AddNative>>('forja_add').asFunction(),
        forja_episode_matches = lib
            .lookup<ffi.NativeFunction<_EpisodeMatchesNative>>(
              'forja_episode_matches',
            )
            .asFunction(),
        forja_normalize_torrent_title = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_normalize_torrent_title',
            )
            .asFunction(),
        forja_unpack_js = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>('forja_unpack_js')
            .asFunction(),
        forja_build_movie_url = lib
            .lookup<ffi.NativeFunction<_BuildMovieUrlNative>>(
              'forja_build_movie_url',
            )
            .asFunction(),
        forja_build_tv_url = lib
            .lookup<ffi.NativeFunction<_BuildTvUrlNative>>('forja_build_tv_url')
            .asFunction(),
        forja_list_providers_json = lib
            .lookup<ffi.NativeFunction<_VersionNative>>(
              'forja_list_providers_json',
            )
            .asFunction(),
        forja_parse_m3u_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_m3u_json',
            )
            .asFunction(),
        forja_decrypt_paste_response = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_decrypt_paste_response',
            )
            .asFunction(),
        forja_decode_xtream_text = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_decode_xtream_text',
            )
            .asFunction(),
        forja_parse_xtream_categories_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_xtream_categories_json',
            )
            .asFunction(),
        forja_parse_xtream_streams_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_parse_xtream_streams_json',
            )
            .asFunction(),
        forja_parse_xtream_series_episodes_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_xtream_series_episodes_json',
            )
            .asFunction(),
        forja_parse_scene_info_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_scene_info_json',
            )
            .asFunction(),
        forja_parse_hls_master_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_parse_hls_master_json',
            )
            .asFunction(),
        forja_decrypt_kisskh_body = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_decrypt_kisskh_body',
            )
            .asFunction(),
        forja_build_stremio_resource_url = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_build_stremio_resource_url',
            )
            .asFunction(),
        forja_normalize_stremio_manifest_url = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_normalize_stremio_manifest_url',
            )
            .asFunction(),
        forja_split_stremio_addon_url_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_split_stremio_addon_url_json',
            )
            .asFunction(),
        forja_parse_stremio_manifest_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_stremio_manifest_json',
            )
            .asFunction(),
        forja_parse_stremio_streams_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_stremio_streams_json',
            )
            .asFunction(),
        forja_parse_stremio_subtitles_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_stremio_subtitles_json',
            )
            .asFunction(),
        forja_parse_stremio_catalog_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_stremio_catalog_json',
            )
            .asFunction(),
        forja_parse_stremio_meta_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_stremio_meta_json',
            )
            .asFunction(),
        forja_stremio_http_get_json = lib
            .lookup<ffi.NativeFunction<_StremioHttpGetNative>>(
              'forja_stremio_http_get_json',
            )
            .asFunction(),
        forja_parse_knaben_html_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_knaben_html_json',
            )
            .asFunction(),
        forja_parse_tpb_html_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_tpb_html_json',
            )
            .asFunction(),
        forja_parse_uindex_html_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_parse_uindex_html_json',
            )
            .asFunction(),
        forja_dedup_torrents_json = lib
            .lookup<ffi.NativeFunction<_StringInOutNative>>(
              'forja_dedup_torrents_json',
            )
            .asFunction(),
        forja_extract_embed_html_json = lib
            .lookup<ffi.NativeFunction<_ThreeStringNative>>(
              'forja_extract_embed_html_json',
            )
            .asFunction(),
        forja_extract_vidsrc_chain_json = lib
            .lookup<ffi.NativeFunction<_ThreeStringNative>>(
              'forja_extract_vidsrc_chain_json',
            )
            .asFunction(),
        forja_extract_hubcloud_links_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_extract_hubcloud_links_json',
            )
            .asFunction(),
        forja_extract_mfp_embed_html_json = lib
            .lookup<ffi.NativeFunction<_FiveStringNative>>(
              'forja_extract_mfp_embed_html_json',
            )
            .asFunction(),
        forja_resolve_webstreamr_source_json = lib
            .lookup<ffi.NativeFunction<_TwoStringNative>>(
              'forja_resolve_webstreamr_source_json',
            )
            .asFunction(),
        forja_extract_kinoger_episode_urls_json = lib
            .lookup<ffi.NativeFunction<_KinogerUrlsNative>>(
              'forja_extract_kinoger_episode_urls_json',
            )
            .asFunction(),
        forja_parse_webstreamr_source_html_json = lib
            .lookup<ffi.NativeFunction<_ThreeStringNative>>(
              'forja_parse_webstreamr_source_html_json',
            )
            .asFunction(),
        forja_torrent_start = lib
            .lookup<ffi.NativeFunction<_TorrentStartNative>>(
              'forja_torrent_start',
            )
            .asFunction(),
        forja_torrent_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>('forja_torrent_stop')
            .asFunction(),
        forja_torrent_is_running = lib
            .lookup<ffi.NativeFunction<_TorrentIsRunningNative>>(
              'forja_torrent_is_running',
            )
            .asFunction(),
        forja_torrent_status_json = lib
            .lookup<ffi.NativeFunction<_VersionNative>>(
              'forja_torrent_status_json',
            )
            .asFunction(),
        forja_torrent_engine_start = lib
            .lookup<ffi.NativeFunction<_ProxyStartNative>>(
              'forja_torrent_engine_start',
            )
            .asFunction(),
        forja_torrent_engine_port = lib
            .lookup<ffi.NativeFunction<_ProxyPortNative>>(
              'forja_torrent_engine_port',
            )
            .asFunction(),
        forja_torrent_engine_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>(
              'forja_torrent_engine_stop',
            )
            .asFunction(),
        forja_torrent_stream_json = lib
            .lookup<ffi.NativeFunction<_TorrentStreamJsonNative>>(
              'forja_torrent_stream_json',
            )
            .asFunction(),
        forja_torrent_list_files_json = lib
            .lookup<ffi.NativeFunction<_TorrentJsonNative>>(
              'forja_torrent_list_files_json',
            )
            .asFunction(),
        forja_proxy_start = lib
            .lookup<ffi.NativeFunction<_ProxyStartNative>>('forja_proxy_start')
            .asFunction(),
        forja_proxy_stop = lib
            .lookup<ffi.NativeFunction<_TorrentStopNative>>('forja_proxy_stop')
            .asFunction(),
        forja_proxy_port = lib
            .lookup<ffi.NativeFunction<_ProxyPortNative>>('forja_proxy_port')
            .asFunction(),
        forja_proxy_register_route = lib
            .lookup<ffi.NativeFunction<_ProxyRegisterNative>>(
              'forja_proxy_register_route',
            )
            .asFunction();

  final void Function(ffi.Pointer<ffi.Char>) forja_free_string;
  final ffi.Pointer<ffi.Char> Function() forja_version;
  final int Function(int, int) forja_add;
  final bool Function(ffi.Pointer<ffi.Char>, int, int) forja_episode_matches;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_normalize_torrent_title;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) forja_unpack_js;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, int)
      forja_build_movie_url;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    int,
    int,
  ) forja_build_tv_url;
  final ffi.Pointer<ffi.Char> Function() forja_list_providers_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_m3u_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_decrypt_paste_response;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_decode_xtream_text;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_xtream_categories_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_parse_xtream_streams_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_xtream_series_episodes_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_scene_info_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_parse_hls_master_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_decrypt_kisskh_body;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_build_stremio_resource_url;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_normalize_stremio_manifest_url;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_split_stremio_addon_url_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_stremio_manifest_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_stremio_streams_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_stremio_subtitles_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_stremio_catalog_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_stremio_meta_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, int)
      forja_stremio_http_get_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_knaben_html_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_tpb_html_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_parse_uindex_html_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_dedup_torrents_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_extract_embed_html_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_extract_vidsrc_chain_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_extract_hubcloud_links_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_extract_mfp_embed_html_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_resolve_webstreamr_source_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    int,
  ) forja_extract_kinoger_episode_urls_json;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_parse_webstreamr_source_html_json;
  final bool Function(ffi.Pointer<ffi.Char>) forja_torrent_start;
  final void Function() forja_torrent_stop;
  final bool Function() forja_torrent_is_running;
  final ffi.Pointer<ffi.Char> Function() forja_torrent_status_json;
  final int Function(int) forja_torrent_engine_start;
  final int Function() forja_torrent_engine_port;
  final void Function() forja_torrent_engine_stop;
  final ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>,
    int,
    int,
    int,
  ) forja_torrent_stream_json;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      forja_torrent_list_files_json;
  final int Function(int) forja_proxy_start;
  final void Function() forja_proxy_stop;
  final int Function() forja_proxy_port;
  final bool Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) forja_proxy_register_route;
}

typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<ffi.Char>);
typedef _VersionNative = ffi.Pointer<ffi.Char> Function();
typedef _AddNative = ffi.Int64 Function(ffi.Int64, ffi.Int64);
typedef _EpisodeMatchesNative = ffi.Bool Function(
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
typedef _TorrentStartNative = ffi.Bool Function(ffi.Pointer<ffi.Char>);
typedef _TorrentStopNative = ffi.Void Function();
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
