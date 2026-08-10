import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Discovers VidSrc.sbs multi-server mirrors from the outer embed HTML.
///
/// The public page hides mirrors (PRO Multi / Cinesrc / 4K / …) in a
/// dropdown. During resolve we parse `CFG.servers` and sniff every nested
/// embed (bounded parallel). Each nested player rotates its own Servers
/// chips so internals land in Sources.
class VidsrcsbsExtractor {
  VidsrcsbsExtractor({this.onLog, http.Client? client})
    : _client = client ?? http.Client();

  final void Function(String)? onLog;
  final http.Client _client;

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static var _generation = 0;

  static void cancelPending() => _generation++;

  void _log(String msg) {
    final line = '[vidsrcsbs] $msg';
    onLog?.call(line);
    debugPrint(line);
  }

  /// Fetch [embedUrl] and return nested server embeds in preferred order.
  Future<List<VidsrcsbsServer>> discoverServers({
    required String embedUrl,
    bool Function()? isCancelled,
  }) async {
    final gen = _generation;
    bool cancelled() =>
        gen != _generation || (isCancelled?.call() ?? false);

    try {
      _log('discover $embedUrl');
      final res = await _client
          .get(
            Uri.parse(embedUrl),
            headers: {
              'User-Agent': userAgent,
              'Accept': 'text/html,application/xhtml+xml',
              'Referer': 'https://vidsrc.sbs/',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (cancelled()) return const [];
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _log('discover HTTP ${res.statusCode}');
        return const [];
      }
      final servers = parseServersHtml(res.body);
      if (servers.isEmpty) {
        _log('discover: no CFG.servers in HTML');
        return const [];
      }
      _log(
        'discover: ${servers.map((s) => s.name).join(', ')}',
      );
      return servers;
    } catch (e) {
      _log('discover error: $e');
      return const [];
    }
  }

  /// Parse `servers: [...]` from the embed page inline script.
  static List<VidsrcsbsServer> parseServersHtml(String html) {
    final raw = _extractServersJson(html);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final parsed = <VidsrcsbsServer>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().trim() ?? '';
        final movieUrl = map['movie_url']?.toString() ?? '';
        final tvUrl = map['tv_url']?.toString() ?? '';
        if (name.isEmpty || (movieUrl.isEmpty && tvUrl.isEmpty)) continue;
        parsed.add(
          VidsrcsbsServer(
            id: map['id']?.toString() ?? name,
            name: name,
            movieUrlTemplate: movieUrl,
            tvUrlTemplate: tvUrl,
          ),
        );
      }
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  static String? _extractServersJson(String html) {
    final marker = html.indexOf('servers:');
    if (marker < 0) return null;
    final start = html.indexOf('[', marker);
    if (start < 0) return null;
    var depth = 0;
    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (c == '[') {
        depth++;
      } else if (c == ']') {
        depth--;
        if (depth == 0) {
          return html.substring(start, i + 1);
        }
      }
    }
    return null;
  }
}

class VidsrcsbsServer {
  const VidsrcsbsServer({
    required this.id,
    required this.name,
    required this.movieUrlTemplate,
    required this.tvUrlTemplate,
  });

  final String id;
  final String name;
  final String movieUrlTemplate;
  final String tvUrlTemplate;

  String resolveUrl({
    required bool isMovie,
    required String tmdbId,
    int? season,
    int? episode,
  }) {
    final tpl = isMovie ? movieUrlTemplate : tvUrlTemplate;
    return tpl
        .replaceAll('{tmdb_id}', tmdbId)
        .replaceAll('{season}', '${season ?? 1}')
        .replaceAll('{episode}', '${episode ?? 1}');
  }
}
