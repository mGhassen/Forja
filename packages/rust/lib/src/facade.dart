import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';
import 'library_path.dart';

/// Rust engine facade — native library required for parser/torrent features.
abstract final class ForjaEngine {
  static bool _enabled = false;
  static bool _initialized = false;

  static bool get isReady => _enabled && ForjaRust.isInitialized;

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
          await ForjaRust.init(libraryPath: candidate);
          _enabled = true;
          final storePath = storagePath ?? await _defaultStoragePath();
          _openStorage(storePath);
          try {
            await _migrateLegacyPrefsIfNeeded();
          } catch (e) {
            debugPrint('[ForjaEngine] legacy prefs migration skipped: $e');
          }
          debugPrint(
            '[ForjaEngine] Rust engine v${ForjaRust.instance.version} ($candidate)',
          );
          return;
        } catch (e) {
          lastError = e;
        }
      }
      debugPrint('[ForjaEngine] Rust library not loaded: $lastError');
      _enabled = false;
    } catch (e) {
      debugPrint('[ForjaEngine] init failed: $e');
      _enabled = false;
    }
  }

  static Future<String> _defaultStoragePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'forja_engine_store.json');
  }

  static void _openStorage(String path) {
    final raw = ForjaRust.instance.storageOpen(path);
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed.containsKey('error')) {
      throw StateError('storage_open failed: ${parsed['error']}');
    }
    debugPrint('[ForjaEngine] storage: $path');
  }

  static void _requireReady() {
    if (!isReady) {
      throw StateError(
        'Rust engine not loaded — run ./scripts/build_rust.sh (desktop) '
        'or ./scripts/build_rust_mobile.sh (mobile)',
      );
    }
  }

  static String? buildMovieUrl(String providerId, String tmdbId) {
    if (!isReady) return null;
    final id = int.tryParse(tmdbId);
    if (id == null) return null;
    final url = ForjaRust.instance.buildMovieUrl(providerId, id);
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
        ForjaRust.instance.buildTvUrl(providerId, id, season, episode);
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

  static List<Map<String, dynamic>> parseM3uChannels(String content) {
    _requireReady();
    final json = ForjaRust.instance.parseM3uJson(content);
    final decoded = jsonDecode(json);
    if (decoded is Map && decoded['error'] != null) {
      throw FormatException(decoded['error'] as String);
    }
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  static String normalizeTorrentTitle(String title) {
    if (!isReady) return title;
    return ForjaRust.instance.normalizeTorrentTitle(title);
  }

  static List<Map<String, dynamic>> searchTorrents(String query) {
    _requireReady();
    final json = ForjaRust.instance.searchTorrentsJson(query);
    return (jsonDecode(json) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static List<Map<String, dynamic>> filterTorrents(
    List<Map<String, dynamic>> results,
    String showTitle, {
    int? requiredSeason,
    int? requiredEpisode,
  }) {
    _requireReady();
    final json = ForjaRust.instance.filterTorrentsJson(
      jsonEncode(results),
      showTitle,
      requiredSeason: requiredSeason ?? -1,
      requiredEpisode: requiredEpisode ?? -1,
    );
    return (jsonDecode(json) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static List<Map<String, dynamic>> sortTorrents(
    List<Map<String, dynamic>> results,
    String preference,
  ) {
    _requireReady();
    final json = ForjaRust.instance.sortTorrentsJson(
      jsonEncode(results),
      preference,
    );
    return (jsonDecode(json) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static bool isVideoFile(String fileName) {
    _requireReady();
    return ForjaRust.instance.isVideoFile(fileName);
  }

  // ── Engine KV store (crates/storage via FFI) ─────────────────────────────

  static bool storageHasKey(String key) {
    _requireReady();
    return ForjaRust.instance.storageGetJson(key) != 'null';
  }

  static dynamic storageRead(String key) {
    _requireReady();
    final raw = ForjaRust.instance.storageGetJson(key);
    if (raw == 'null') return null;
    return jsonDecode(raw);
  }

  static void storageWrite(String key, Object value) {
    _requireReady();
    final resp = jsonDecode(
      ForjaRust.instance.storageSetJson(key, jsonEncode(value)),
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

  /// One-time import from legacy SharedPreferences keys into Rust KV.
  static Future<void> _migrateLegacyPrefsIfNeeded() async {
    if (!isReady) return;
    if (storageHasKey('forja_provider_order')) return;

    final prefs = await SharedPreferences.getInstance();

    void migrateStringList(String key) {
      final list = prefs.getStringList(key);
      if (list != null) storageWriteStringList(key, list);
    }

    void migrateString(String key) {
      final s = prefs.getString(key);
      if (s != null) storageWriteString(key, s);
    }

    void migrateBool(String key) {
      if (prefs.containsKey(key)) {
        storageWriteBool(key, prefs.getBool(key) ?? false);
      }
    }

    migrateStringList('forja_provider_order');
    migrateStringList('forja_enabled_providers');
    migrateString('forja_last_provider');
    migrateStringList('stream_provider_order');

    final stremio = prefs.getStringList('stremio_addons');
    if (stremio != null && stremio.isNotEmpty) {
      storageWriteMapList(
        'stremio_addons',
        stremio.map((s) => jsonDecode(s) as Map<String, dynamic>).toList(),
      );
    }

    migrateBool('forja_auto_next');
    migrateString('forja_external_player');

    final iptvGroups = prefs.getString('forja_iptv_groups');
    if (iptvGroups != null) storageWriteString('forja_iptv_groups', iptvGroups);

    final iptvMeta = prefs.getString('forja_iptv_portal_meta');
    if (iptvMeta != null) storageWriteString('forja_iptv_portal_meta', iptvMeta);

    void migrateInt(String key) {
      if (prefs.containsKey(key)) {
        storageWrite(key, prefs.getInt(key)!);
      }
    }

    void migrateDouble(String key) {
      if (prefs.containsKey(key)) {
        storageWrite(key, prefs.getDouble(key)!);
      }
    }

    const stringKeys = [
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
    ];
    for (final k in stringKeys) {
      migrateString(k);
    }

    const boolKeys = [
      'streaming_mode',
      'use_debrid_for_streams',
      'light_mode',
      'sub_bold',
      'avoid_unsupported_audio',
    ];
    for (final k in boolKeys) {
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

    void migrateJsonList(String key) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) storageWrite(key, decoded);
      } catch (_) {}
    }

    migrateJsonList('watch_history');
    migrateJsonList('dismissed_history');
  }
}
