import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// FFI client for the Rust Resolver Engine (`crates/resolver-engine`).
abstract final class ResolverEngineClient {
  static Future<Map<String, dynamic>> resolve({
    required Map<String, dynamic> request,
  }) async {
    if (!Engine.isReady) await Engine.init();
    final raw = await EngineJobs.run(
      EngineAsyncJob.resolverEngineResolve,
      {'requestJson': jsonEncode(request)},
    );
    return _parseResponse(raw);
  }

  static Future<Map<String, dynamic>> continueWithHost({
    required String sessionId,
    required List<Map<String, dynamic>> hostResults,
  }) async {
    final raw = await EngineJobs.run(
      EngineAsyncJob.resolverEngineContinue,
      {
        'requestJson': jsonEncode({
          'sessionId': sessionId,
          'hostResults': hostResults,
        }),
      },
    );
    return _parseResponse(raw);
  }

  static Map<String, dynamic> _parseResponse(String raw) {
    final parsed = jsonDecode(raw);
    if (parsed is! Map) {
      throw StateError('ResolverEngine invalid JSON: $raw');
    }
    final map = Map<String, dynamic>.from(parsed);
    if (map['error'] != null) {
      debugPrint('[ResolverEngine] error: ${map['error']}');
    }
    return map;
  }

  static Future<Map<String, dynamic>> buildRequest({
    required SourceDomain domain,
    required Movie movie,
    required int season,
    required int episode,
    required Map<String, dynamic> providers,
    List<String> settingsOrder = const [],
    String preferred = SourceEngine.auto,
    bool skipHostOnTv = false,
    List<String> blocklistUrls = const [],
    int maxInFlight = 2,
  }) async {
    final device = await DeviceCapabilitiesService.detect();
    final year = movie.releaseDate.length >= 4
        ? int.tryParse(movie.releaseDate.substring(0, 4))
        : null;
    final webstreamrConfig = await WebStreamrSettings.buildResolveConfig();
    final webstreamrToken = await WebStreamrSettings.getTmdbAccessToken();
    return {
      'domain': domain.id,
      'tmdbId': movie.id,
      'imdbId': movie.imdbId ?? '',
      'title': movie.title,
      'year': year,
      'season': season,
      'episode': episode,
      'mediaType': movie.mediaType,
      'device': device.toJson(),
      'providersJson': jsonEncode(providers.keys.toList()),
      'settings': {
        'enabledProviderIds': providers.keys.toList(),
        'settingsOrder': settingsOrder,
        'preferred': preferred,
        'maxInFlight': maxInFlight,
        'skipHostOnTv': skipHostOnTv,
        'blocklistUrls': blocklistUrls,
        'webstreamrConfig': webstreamrConfig,
        'webstreamrTmdbAccessToken': webstreamrToken ?? '',
      },
    };
  }

  static List<PlayableSource> sourcesFromResponse(Map<String, dynamic> response) {
    final raw = response['sources'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => PlayableSource.fromJson(Map<String, dynamic>.from(m)))
        .where((s) => s.url.trim().isNotEmpty)
        .toList();
  }

  static PlayableSource? winnerFromResponse(Map<String, dynamic> response) {
    final winner = response['winner'];
    if (winner is Map) {
      return PlayableSource.fromJson(Map<String, dynamic>.from(winner));
    }
    final sources = sourcesFromResponse(response);
    return sources.isEmpty ? null : sources.first;
  }
}
