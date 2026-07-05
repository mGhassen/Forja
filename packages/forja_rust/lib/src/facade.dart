import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja_core/utils/episode_matcher.dart';
import 'package:forja_core/utils/hls_master_parser.dart';

import 'engine.dart';
import 'library_path.dart';
import 'reference/episode_matcher_dart.dart';
import 'reference/hls_dart_parse.dart';

/// Routes hot-path engine calls to Rust when loaded, else Dart fallbacks.
abstract final class ForjaEngine {
  static bool _enabled = false;
  static bool _initialized = false;

  static bool get isReady => _enabled && ForjaRust.isInitialized;

  /// Load the native library. Non-fatal on failure — Dart fallbacks stay active.
  static Future<void> init({bool? enabled}) async {
    if (_initialized) return;
    _initialized = true;

    final wantRust = enabled ?? true;
    if (!wantRust) {
      _enabled = false;
      _installUtilityBackends();
      return;
    }

    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      _enabled = false;
      _installUtilityBackends();
      return;
    }

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
      debugPrint('[ForjaEngine] Rust library not loaded — Dart fallback: $lastError');
      _enabled = false;
      _installUtilityBackends();
    } catch (e) {
      debugPrint('[ForjaEngine] init failed (Dart fallback): $e');
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

    EpisodeMatcherBackend.matches = EpisodeMatcherDart.matches;
    HlsParserBackend.parseMaster = HlsDartParse.parseMaster;
  }

  static String? buildMovieUrl(String providerId, String tmdbId) {
    if (!isReady) return null;
    final id = int.tryParse(tmdbId);
    if (id == null) return null;
    final url = ForjaRust.instance.buildMovieUrl(providerId, id);
    return url.isEmpty ? null : url;
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

  static List<Map<String, dynamic>> parseM3uChannels(String content) {
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
