import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// Direct HTTP client for animerealms.org API.
/// Uses the same AniList IDs as Miruro.
class AnimeRealmsExtractor {
  static const String _baseUrl = 'https://www.animerealms.org';
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': '$_baseUrl/',
    'Origin': _baseUrl,
  };

  Future<Map<String, dynamic>> getMappings(int anilistId, {String? provider}) async {
    final query = provider != null
        ? 'id=$anilistId&provider=$provider'
        : 'id=$anilistId';
    final res = await animeHttp(
      'GET',
      '$_baseUrl/api/mappings?$query',
      headers: _headers,
      maxRetries: 0,
    );
    if (res.status != 200) {
      throw Exception('AnimeRealms mappings HTTP ${res.status}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStreams({
    required String provider,
    required int anilistId,
    required int episodeNumber,
  }) async {
    final res = await animeHttp(
      'POST',
      '$_baseUrl/api/watch',
      headers: {
        ..._headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'provider': provider,
        'anilistId': anilistId,
        'episodeNumber': episodeNumber,
      }),
      maxRetries: 0,
    );
    if (res.status != 200) {
      throw Exception('AnimeRealms watch HTTP ${res.status}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Resolve streams for a single provider (used by the parallel embed race).
  Future<AnimeRealmsResult?> extractWithProvider({
    required int anilistId,
    required int episodeNumber,
    required String provider,
  }) async {
    try {
      final data = await getStreams(
        provider: provider,
        anilistId: anilistId,
        episodeNumber: episodeNumber,
      );
      final streams = data['streams'] as List?;
      if (streams == null || streams.isEmpty) return null;
      final real = streams
          .where((s) =>
              s is Map &&
              s['url'] != null &&
              !(s['url'] as String).contains('test-streams.mux.dev'))
          .cast<Map>()
          .toList();
      if (real.isEmpty) return null;
      final first = real.first;
      final url = first['url'] as String;
      final tracks = <AnimeRealmsTrack>[];
      final subs = data['subtitles'];
      if (subs is List) {
        for (final t in subs) {
          if (t is! Map) continue;
          final su = t['url']?.toString();
          if (su == null || su.isEmpty) continue;
          tracks.add(AnimeRealmsTrack(
            url: su,
            label: (t['lang'] ?? t['label'] ?? 'Unknown').toString(),
            isDefault: t['default'] == true,
          ));
        }
      }
      return AnimeRealmsResult(
        url: url,
        referer: '$_baseUrl/',
        origin: _baseUrl,
        provider: provider,
        tracks: tracks,
      );
    } catch (e) {
      debugPrint('[AnimeRealms] $provider failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSources({
    required int anilistId,
    required int episodeNumber,
  }) async {
    Map<String, dynamic> mappings;
    try {
      mappings = await getMappings(anilistId);
    } catch (e) {
      debugPrint('[AnimeRealms] Failed to get mappings: $e');
      mappings = {};
    }

    final providerNames = getProviderNames(mappings);
    debugPrint(
        '[AnimeRealms] Trying ${providerNames.length} providers for '
        '$anilistId ep $episodeNumber');

    final results = <Map<String, dynamic>>[];
    for (final provider in providerNames) {
      try {
        final data = await getStreams(
          provider: provider,
          anilistId: anilistId,
          episodeNumber: episodeNumber,
        );
        final streams = data['streams'] as List?;
        if (streams == null || streams.isEmpty) continue;
        final real = streams
            .where((s) =>
                s is Map &&
                s['url'] != null &&
                !(s['url'] as String).contains('test-streams.mux.dev'))
            .toList();
        if (real.isEmpty) continue;
        debugPrint('[AnimeRealms] OK $provider: ${real.length} stream(s)');
        results.add({
          'provider': provider,
          'streams': real,
          'subtitles': data['subtitles'] ?? [],
        });
      } catch (e) {
        debugPrint('[AnimeRealms] $provider failed: $e');
      }
    }
    return results;
  }

  static List<String> getProviderNames(Map<String, dynamic> mappings) {
    if (mappings.isEmpty) return defaultProviders;
    final names = mappings.keys
        .where((k) => mappings[k] is String || mappings[k] is num)
        .toList();
    return names.isNotEmpty ? names : defaultProviders;
  }

  static const List<String> defaultProviders = [
    'hianime',
    'allmanga',
    'gogoanime',
    'zencloud',
    'animepahe',
    'animez',
    'animekai',
    'kickassanime',
    'anizone',
    'febbox',
    'hanime-tv',
  ];
}

class AnimeRealmsResult {
  final String url;
  final String referer;
  final String origin;
  final String provider;
  final List<AnimeRealmsTrack> tracks;

  const AnimeRealmsResult({
    required this.url,
    required this.referer,
    required this.origin,
    required this.provider,
    this.tracks = const [],
  });
}

class AnimeRealmsTrack {
  final String url;
  final String label;
  final bool isDefault;

  const AnimeRealmsTrack({
    required this.url,
    required this.label,
    this.isDefault = false,
  });
}
