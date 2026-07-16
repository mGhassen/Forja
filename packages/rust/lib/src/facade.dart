import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';
import 'engine_jobs.dart';
import 'engine_worker.dart';
import 'isolate_runner.dart';
import 'library_path.dart';

/// Rust engine facade — native library required for parser/torrent features.
abstract final class Engine {
  static bool _enabled = false;
  static bool _initialized = false;
  static String? _libraryPath;

  static bool get isReady => _enabled && RustLib.isInitialized;

  /// Dylib path loaded on the main isolate — pass to worker isolates.
  static String? get libraryPath => _libraryPath;

  /// Load the native library. Required for engine features.
  static Future<void> init({String? storagePath}) async {
    if (_initialized) return;
    _initialized = true;

    try {
      Object? lastError;
      for (final candidate in rustLibraryCandidates()) {
        if (candidate.contains('..') ||
            candidate.startsWith('/') ||
            candidate.contains(':\\')) {
          if (!File(candidate).existsSync()) continue;
        }
        try {
          await RustLib.init(libraryPath: candidate);
          RustLib.instance.engineClearShutdown();
          _enabled = true;
          _libraryPath = RustLib.loadedLibraryPath ?? candidate;
          final storePath = storagePath ?? await _defaultStoragePath();
          _openStorage(storePath);
          try {
            await _migrateLegacyPrefsIfNeeded();
          } catch (e) {
            debugPrint('[Engine] legacy prefs migration skipped: $e');
          }
          debugPrint(
            'Rust engine v${RustLib.instance.version} ($candidate)',
          );
          await EngineWorkerPool.start(_libraryPath!);
          return;
        } catch (e, st) {
          RustLib.reset();
          lastError = e;
          debugPrint('[Engine] candidate "$candidate" failed: $e');
          if (kDebugMode) debugPrint('[Engine] stack: $st');
        }
      }
      debugPrint('[Engine] Rust library not loaded: $lastError');
      _enabled = false;
    } catch (e) {
      debugPrint('[Engine] init failed: $e');
      _enabled = false;
    }
  }

  static Future<String> _defaultStoragePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'forja_engine_store.json');
  }

  static void _openStorage(String path) {
    final raw = RustLib.instance.storageOpen(path);
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) {
      throw StateError('storage_open failed: ${parsed['error']}');
    }
    debugPrint('[Engine] storage: $path');
  }

  static void _requireReady() {
    if (!isReady) {
      throw StateError(
        'Rust engine not loaded — run ./scripts/build_rust.sh (desktop) '
        'or ./scripts/build_rust_mobile.sh (mobile)',
      );
    }
  }

  static void cancelPendingResolve() {
    if (!isReady) return;
    RustLib.instance.engineCancelPending();
  }

  /// Tear down worker isolates and async job polling before process exit.
  static Future<void> shutdown() async {
    EngineJobs.shutdown();
    await EngineWorkerPool.shutdown();
  }

  static String? buildMovieUrl(String providerId, String tmdbId) {
    if (!isReady) return null;
    final id = int.tryParse(tmdbId);
    if (id == null) return null;
    final url = RustLib.instance.buildMovieUrl(providerId, id);
    return url.isEmpty ? null : url;
  }

  static String requireMovieUrl(String providerId, String tmdbId) {
    final url = buildMovieUrl(providerId, tmdbId);
    if (url == null) {
      _requireReady();
      throw StateError('No movie URL for provider $providerId');
    }
    return url;
  }

  static String? buildTvUrl(
    String providerId,
    String tmdbId,
    int season,
    int episode,
  ) {
    if (!isReady) return null;
    final id = int.tryParse(tmdbId);
    if (id == null) return null;
    final url =
        RustLib.instance.buildTvUrl(providerId, id, season, episode);
    return url.isEmpty ? null : url;
  }

  static String requireTvUrl(
    String providerId,
    String tmdbId,
    int season,
    int episode,
  ) {
    final url = buildTvUrl(providerId, tmdbId, season, episode);
    if (url == null) {
      _requireReady();
      throw StateError('No TV URL for provider $providerId');
    }
    return url;
  }

  static Future<List<Map<String, dynamic>>> parseM3uChannels(String content) async {
    _requireReady();
    final json = await runParseM3uJson(content);
    final decoded = jsonDecode(json);
    if (decoded is Map && decoded['error'] != null) {
      throw FormatException(decoded['error'] as String);
    }
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  static String normalizeTorrentTitle(String title) {
    if (!isReady) return title;
    return RustLib.instance.normalizeTorrentTitle(title);
  }

  static Future<List<Map<String, dynamic>>> searchTorrents(String query) async {
    _requireReady();
    final json = await runSearchTorrentsJson(query);
    return (jsonDecode(json) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> filterTorrents(
    List<Map<String, dynamic>> results,
    String showTitle, {
    int? requiredSeason,
    int? requiredEpisode,
  }) async {
    _requireReady();
    final json = await runFilterTorrentsJson(
      jsonEncode(results),
      showTitle,
      requiredSeason: requiredSeason ?? -1,
      requiredEpisode: requiredEpisode ?? -1,
    );
    return (jsonDecode(json) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> sortTorrents(
    List<Map<String, dynamic>> results,
    String preference,
  ) async {
    _requireReady();
    final json = await runSortTorrentsJson(jsonEncode(results), preference);
    return (jsonDecode(json) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static bool isVideoFile(String fileName) {
    _requireReady();
    return RustLib.instance.isVideoFile(fileName);
  }

  // ── Engine KV store (crates/storage via FFI) ─────────────────────────────

  static bool storageHasKey(String key) {
    _requireReady();
    return RustLib.instance.storageGetJson(key) != 'null';
  }

  static dynamic storageRead(String key) {
    _requireReady();
    final raw = RustLib.instance.storageGetJson(key);
    if (raw == 'null') return null;
    return jsonDecode(raw);
  }

  static void storageWrite(String key, Object value) {
    _requireReady();
    final resp = jsonDecode(
      RustLib.instance.storageSetJson(key, jsonEncode(value)),
    ) as Map<String, dynamic>;
    if (resp.containsKey('error')) {
      throw StateError('storage_set failed: ${resp['error']}');
    }
  }

  static bool storageReadBool(String key, {required bool fallback}) {
    final v = storageRead(key);
    return v is bool ? v : fallback;
  }

  static void storageWriteBool(String key, bool value) =>
      storageWrite(key, value);

  static String storageReadString(String key, {required String fallback}) {
    final v = storageRead(key);
    return v is String ? v : fallback;
  }

  static void storageWriteString(String key, String value) =>
      storageWrite(key, value);

  static List<String> storageReadStringList(
    String key, {
    required List<String> fallback,
  }) {
    final v = storageRead(key);
    if (v is! List) return List.from(fallback);
    return v.map((e) => '$e').toList();
  }

  static void storageWriteStringList(String key, List<String> values) =>
      storageWrite(key, values);

  static List<Map<String, dynamic>> storageReadMapList(String key) {
    final v = storageRead(key);
    if (v is! List) return [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static void storageWriteMapList(
    String key,
    List<Map<String, dynamic>> values,
  ) =>
      storageWrite(key, values);

  /// Settings live in one place: Rust KV (+ Keychain for secrets).
  /// SharedPreferences is only a one-shot import source, then purged.
  static const String _settingsCanonicalKey = 'settings_canonical_v1';

  /// Prefs keys that belong to the canonical settings file (not caches/lists).
  static const List<String> _settingsPrefsKeys = [
    'forja_provider_order',
    'forja_enabled_providers',
    'forja_last_provider',
    'stream_provider_order',
    'anime_provider_order',
    'stremio_addons',
    'forja_auto_next',
    'forja_external_player',
    'forja_iptv_groups',
    'forja_iptv_portal_meta',
    'sort_preference',
    'debrid_service',
    'external_player',
    'jackett_base_url',
    'jackett_api_key',
    'prowlarr_base_url',
    'prowlarr_api_key',
    'prowlarr_tag_ids',
    'torrent_cache_type',
    'torrent_ram_cache_mb',
    'torrent_connections_limit',
    'theme_preset',
    'preferred_audio_lang',
    'sub_font',
    'sub_color',
    'sub_size',
    'sub_bg_opacity',
    'sub_bottom_padding',
    'sub_bold',
    'streaming_mode',
    'use_debrid_for_streams',
    'light_mode',
    'avoid_unsupported_audio',
    'navbar_config',
    'navbar_known_ids',
    'watch_history',
    'dismissed_history',
    'nuvio_addons_v1',
    'webstreamr_country_codes',
    'webstreamr_mfp_url',
    'webstreamr_flare_url',
    'webstreamr_disabled_extractors',
    'webstreamr_excluded_resolutions',
  ];

  /// Import any leftover SharedPreferences settings into KV, merge Stremio
  /// addons, then delete the prefs copies so there is a single store.
  static Future<void> _migrateLegacyPrefsIfNeeded() async {
    if (!isReady) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyCanonical = storageHasKey(_settingsCanonicalKey);

    if (!alreadyCanonical) {
      void migrateStringList(String key) {
        if (storageHasKey(key)) return;
        final list = prefs.getStringList(key);
        if (list != null) storageWriteStringList(key, list);
      }

      void migrateString(String key) {
        if (storageHasKey(key)) return;
        final s = prefs.getString(key);
        if (s != null) storageWriteString(key, s);
      }

      void migrateBool(String key) {
        if (storageHasKey(key)) return;
        if (prefs.containsKey(key)) {
          storageWriteBool(key, prefs.getBool(key) ?? false);
        }
      }

      void migrateInt(String key) {
        if (storageHasKey(key)) return;
        if (prefs.containsKey(key)) {
          storageWrite(key, prefs.getInt(key)!);
        }
      }

      void migrateDouble(String key) {
        if (storageHasKey(key)) return;
        if (prefs.containsKey(key)) {
          storageWrite(key, prefs.getDouble(key)!);
        }
      }

      void migrateJsonList(String key) {
        if (storageHasKey(key)) return;
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) storageWrite(key, decoded);
        } catch (_) {}
      }

      migrateStringList('forja_provider_order');
      migrateStringList('forja_enabled_providers');
      migrateString('forja_last_provider');
      migrateStringList('stream_provider_order');
      migrateStringList('anime_provider_order');

      // Stremio: merge prefs + KV by baseUrl (KV wins on conflict).
      _mergeStremioAddonsFromPrefs(prefs);

      migrateBool('forja_auto_next');
      migrateString('forja_external_player');
      migrateString('forja_iptv_groups');
      migrateString('forja_iptv_portal_meta');

      for (final k in const [
        'sort_preference',
        'debrid_service',
        'external_player',
        'jackett_base_url',
        'jackett_api_key',
        'prowlarr_base_url',
        'prowlarr_api_key',
        'torrent_cache_type',
        'theme_preset',
        'preferred_audio_lang',
        'sub_font',
      ]) {
        migrateString(k);
      }

      for (final k in const [
        'streaming_mode',
        'use_debrid_for_streams',
        'light_mode',
        'sub_bold',
        'avoid_unsupported_audio',
      ]) {
        migrateBool(k);
      }

      migrateInt('torrent_ram_cache_mb');
      migrateInt('torrent_connections_limit');
      migrateInt('sub_color');
      migrateDouble('sub_size');
      migrateDouble('sub_bg_opacity');
      migrateDouble('sub_bottom_padding');

      migrateStringList('prowlarr_tag_ids');
      migrateStringList('navbar_config');
      migrateStringList('navbar_known_ids');
      migrateJsonList('watch_history');
      migrateJsonList('dismissed_history');

      // Nuvio / WebStreamr non-secrets if still only in prefs.
      if (!storageHasKey('nuvio_addons_v1')) {
        final raw = prefs.getString('nuvio_addons_v1');
        if (raw != null && raw.isNotEmpty) {
          storageWriteString('nuvio_addons_v1', raw);
        }
      }
      migrateStringList('webstreamr_country_codes');
      migrateString('webstreamr_mfp_url');
      migrateString('webstreamr_flare_url');
      migrateStringList('webstreamr_disabled_extractors');
      migrateStringList('webstreamr_excluded_resolutions');
    }

    // Always strip settings keys from prefs — one store only.
    await _purgeSettingsPrefsKeys(prefs);

    if (!alreadyCanonical) {
      storageWriteString(_settingsCanonicalKey, '1');
      debugPrint(
        '[Engine] settings unified into forja_engine_store.json; prefs copies purged',
      );
    }
  }

  static void _mergeStremioAddonsFromPrefs(SharedPreferences prefs) {
    final byUrl = <String, Map<String, dynamic>>{};

    for (final a in storageReadMapList('stremio_addons')) {
      final url = '${a['baseUrl'] ?? ''}'.trim();
      if (url.isEmpty) continue;
      byUrl[url] = a;
    }

    final fromPrefs = prefs.getStringList('stremio_addons');
    if (fromPrefs != null) {
      for (final raw in fromPrefs) {
        try {
          final a = jsonDecode(raw) as Map<String, dynamic>;
          final url = '${a['baseUrl'] ?? ''}'.trim();
          if (url.isEmpty) continue;
          // Prefer existing KV entry when both have the same addon.
          byUrl.putIfAbsent(url, () => a);
        } catch (_) {}
      }
    }

    if (byUrl.isNotEmpty) {
      storageWriteMapList('stremio_addons', byUrl.values.toList());
    }
  }

  static Future<void> _purgeSettingsPrefsKeys(SharedPreferences prefs) async {
    var removed = 0;
    for (final key in _settingsPrefsKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
        removed++;
      }
    }
    if (removed > 0) {
      debugPrint('[Engine] purged $removed settings key(s) from SharedPreferences');
    }
  }
}
