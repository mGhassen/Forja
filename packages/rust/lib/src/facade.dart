import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:core/utils/episode_matcher.dart';
import 'package:core/utils/hls_master_parser.dart';

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
          _installUtilityBackends();
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
      _installUtilityBackends();
    } catch (e) {
      debugPrint('[ForjaEngine] init failed: $e');
      _enabled = false;
      _installUtilityBackends();
    }
  }

  static void _installUtilityBackends() {
    if (_enabled && ForjaRust.isInitialized) {
      EpisodeMatcherBackend.matches = (file, season, episode) =>
          ForjaRust.instance.episodeMatches(file, season, episode);

      HlsParserBackend.parseMaster = (masterUrl, body) {
        final json = ForjaRust.instance.parseHlsMasterJson(masterUrl, body);
        final list = jsonDecode(json) as List;
        if (list.isEmpty) return null;
        return list.map((e) {
          final m = e as Map<String, dynamic>;
          return HlsQuality(
            label: m['label'] as String,
            url: m['url'] as String,
            bandwidth: m['bandwidth'] as int?,
            height: m['height'] as int?,
            isAuto: m['is_auto'] as bool? ?? false,
          );
        }).toList();
      };
      return;
    }

    EpisodeMatcherBackend.matches = null;
    HlsParserBackend.parseMaster = null;
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
}
