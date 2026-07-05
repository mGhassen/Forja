import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'engine.dart';
import 'library_path.dart';

/// Rust engine facade — native library required for parser/torrent features.
abstract final class ForjaEngine {
  static bool _enabled = false;
  static bool _initialized = false;

  static bool get isReady => _enabled && ForjaRust.isInitialized;

  /// Load the native library. Required for engine features.
  static Future<void> init() async {
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
}
