import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/engine/live_goat_webview_unlock.dart';
import 'package:forja/shared/engine/live_gasm_webview_unlock.dart';
import 'package:forja/shared/webview/forja_headless_in_app_webview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Host bridge for `ctx.live.goatUnlock` / `ctx.live.gasmUnlock` —
/// desktop Node WASM decrypt, Android/iOS off-screen WebView fallback.
class LiveGoatUnlock {
  LiveGoatUnlock._();

  static const _assetRoot = 'assets/plugins/live/goat';
  static const _gasmAssetRoot = 'assets/plugins/live/gasm';
  static const _sportsEmbedAssetRoot = 'assets/plugins/live/sportsembed';
  static const _embedOrigin = 'https://embed.st';
  static const _embedIndiaOrigin = 'https://embedindia.st';
  static const _watchfootyReferer = 'https://watchfooty.st/';
  static const _sportsEmbedOrigin = 'https://sportsembed.su';
  static const _sportsEmbedHosts = ['sportsembed.su', 'spiderembed.top'];
  static const _goatSlotSources = {
    'admin',
    'delta',
    'echo',
    'golf',
    'ppv',
    'bravo',
  };
  /// Prefer delta (GOAT-compatible) then denser sportsembed qualities.
  static const _watchfootySourcePriority = [
    'delta',
    'echo',
    'sigma',
    'pro',
    'platinum',
    'deluxe',
    'hd',
    'regular',
  ];
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? _cachedDir;
  static Future<void>? _prepareFuture;

  static String? _cachedGasmDir;
  static Future<void>? _prepareGasmFuture;

  static String? _cachedSportsEmbedDir;
  static Future<void>? _prepareSportsEmbedFuture;

  static bool isSportsEmbedUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return _sportsEmbedHosts.any((h) => host == h || host.endsWith('.$h'));
  }

  static bool isEpiEmbedsUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return host == 'epiembeds.online' || host.endsWith('.epiembeds.online');
  }

  static bool isGasmJwEmbedUrl(String url) =>
      isEmbedIndiaUrl(url) || isEpiEmbedsUrl(url);

  static bool isEmbedIndiaUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return host == 'embedindia.st' || host.endsWith('.embedindia.st');
  }

  /// sportsembed.su mirrors embed.st — `/embed/{event}/{slug}/{source}/{n}`.
  static String? embedStUrlFromSportsEmbed(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !isSportsEmbedUrl(raw)) return null;
    final segs = uri.pathSegments;
    if (segs.length < 5 || segs.first != 'embed') return null;
    final slug = segs[2];
    final source = segs[3].toLowerCase();
    final stream = segs[4];
    if (!_goatSlotSources.contains(source)) return null;
    return '$_embedOrigin/embed/$source/$slug/$stream';
  }

  /// hd / platinum rows on sportsembed map to admin `ppv-…` slots on embed.st.
  static Iterable<String> embedStAdminCandidatesFromSportsEmbed(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !isSportsEmbedUrl(raw)) return const [];
    final segs = uri.pathSegments;
    if (segs.length < 5 || segs.first != 'embed') return const [];
    final slug = segs[2];
    final quality = segs[3].toLowerCase();
    final stream = segs[4];
    if (quality != 'hd' && quality != 'platinum') return const [];

    final parts = slug.split('-').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return const [];

    final ids = <String>{'ppv-$slug'};
    for (var i = 1; i < parts.length; i++) {
      final home = parts.sublist(0, i).join('-');
      final away = parts.sublist(i).join('-');
      ids.add('ppv-$home-vs-$away');
    }
    return ids.map((id) => '$_embedOrigin/embed/admin/$id/$stream');
  }

  @visibleForTesting
  static Map<String, dynamic>? parseEmbedIndiaSlot(String raw) =>
      _parseEmbedIndiaSlot(raw);

  /// Unlock watchfooty.st sportsembed mirrors to a playable HLS URL.
  ///
  /// sportsembed hosts only mirror embed.st slots — map onto embed.st GOAT
  /// (same as PPV/streamed). Never returns an HTML embed URL.
  static Future<({String url, Map<String, String> headers})?>
  resolveWatchfootyEmbed({required String embedUrl}) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty) return null;
    if (RegExp(r'\.m3u8|\.mp4', caseSensitive: false).hasMatch(embed)) {
      return (
        url: embed,
        headers: {
          'Referer': _watchfootyReferer,
          'User-Agent': _ua,
        },
      );
    }
    if (!isSportsEmbedUrl(embed)) return null;

    final mapped = embedStUrlFromSportsEmbed(embed);
    if (mapped != null) {
      final unlocked = await resolveStreamed(embedUrl: mapped);
      if (unlocked != null) return unlocked;
    }

    for (final candidate in embedStAdminCandidatesFromSportsEmbed(embed)) {
      final unlocked = await resolveStreamed(embedUrl: candidate);
      if (unlocked != null) return unlocked;
    }

    return null;
  }

  /// sportsembed.su client handshake → plaintext HLS URL.
  static Future<({String url, Map<String, String> headers})?> resolveSportsEmbed({
    required String embedUrl,
  }) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty || !isSportsEmbedUrl(embed)) return null;
    final slot = parseSportsEmbedSlot(embed);
    if (slot == null) {
      debugPrint('[LiveSportsEmbed] unparseable embed: $embed');
      return null;
    }

    final node = await _findNodeBinary();
    if (node == null) {
      debugPrint('[LiveSportsEmbed] node not found — sportsembed unlock skipped');
      return null;
    }

    try {
      final dir = await _ensureSportsEmbedDir();
      final result = await _runSportsEmbedUnlock(
        node: node,
        dir: dir,
        embedUrl: embed,
      );
      if (result == null || result.isEmpty) return null;
      final origin = (slot['origin'] ?? _sportsEmbedOrigin).toString();
      final path = (slot['path'] ?? '').toString();
      final headers = <String, String>{
        'Referer': path.isNotEmpty ? '$origin/embed/$path' : '$origin/',
        'Origin': origin,
        'User-Agent': _ua,
      };
      // regular/hd often decrypt to a URL that then 500s on the CDN — skip those.
      if (!await _probePlayableM3u8(result, headers)) {
        debugPrint(
          '[LiveSportsEmbed] CDN m3u8 not playable '
          '${Uri.tryParse(result)?.host ?? result}',
        );
        return null;
      }
      return (url: result, headers: headers);
    } catch (e) {
      debugPrint('[LiveSportsEmbed] unlock failed: $e');
      return null;
    }
  }

  /// Fetch WatchFooty match streams and unlock playable HLS rows (delta first).
  static Future<List<({String url, String name, Map<String, String> headers})>>
  resolveWatchfootyMatch({required String matchId}) async {
    final mid = matchId.trim().replaceFirst(RegExp(r'^wf_'), '');
    if (mid.isEmpty) return const [];

    try {
      final streams = await _watchfootyMatchStreams(mid);
      if (streams.isEmpty) return const [];

      final ordered = List<Map<String, dynamic>>.from(streams);
      ordered.sort((a, b) {
        final sa = (a['source'] ?? '').toString().toLowerCase();
        final sb = (b['source'] ?? '').toString().toLowerCase();
        final ia = _watchfootySourcePriority.indexOf(sa);
        final ib = _watchfootySourcePriority.indexOf(sb);
        final pa = ia < 0 ? 99 : ia;
        final pb = ib < 0 ? 99 : ib;
        if (pa != pb) return pa.compareTo(pb);
        return (a['url'] ?? '')
            .toString()
            .compareTo((b['url'] ?? '').toString());
      });

      final pending = <({String embed, String source, String quality})>[];
      final seenEmbeds = <String>{};
      for (final s in ordered) {
        final embed = (s['url'] ?? '').toString().trim();
        if (embed.isEmpty || !seenEmbeds.add(embed)) continue;
        pending.add((
          embed: embed,
          source: (s['source'] ?? '').toString().trim(),
          quality: (s['quality'] ?? '').toString().trim(),
        ));
      }

      // Unlock every unique embed in parallel (site lists them all; CDN-dead
      // rows stay dropped by resolveWatchfootyEmbed probe).
      final unlocked = await Future.wait(
        pending.map((row) async {
          final u = await resolveWatchfootyEmbed(embedUrl: row.embed);
          if (u == null) return null;
          final label = [
            'WatchFooty',
            if (row.source.isNotEmpty) row.source,
            if (row.quality.isNotEmpty) row.quality,
          ].join(' ');
          return (url: u.url, name: label, headers: u.headers);
        }),
      );
      return [for (final row in unlocked) ?row];
    } catch (e) {
      debugPrint('[WatchFooty] match resolve failed: $e');
      return const [];
    }
  }

  /// Prefer `/matches/live` (fast, often already has `streams`) over the slow
  /// `/match/{id}` detail (~15–20s+).
  static Future<List<Map<String, dynamic>>> _watchfootyMatchStreams(
    String mid,
  ) async {
    try {
      final liveResp = await http
          .get(
            Uri.parse('https://api.watchfooty.st/api/v1/matches/live'),
            headers: {'User-Agent': _ua, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (liveResp.statusCode >= 200 && liveResp.statusCode < 300) {
        final decoded = jsonDecode(liveResp.body);
        if (decoded is List) {
          for (final row in decoded) {
            if (row is! Map) continue;
            final id = (row['matchId'] ?? '').toString();
            if (id != mid) continue;
            final streams = row['streams'];
            if (streams is List && streams.isNotEmpty) {
              return [
                for (final s in streams)
                  if (s is Map) Map<String, dynamic>.from(s),
              ];
            }
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[WatchFooty] live list lookup failed: $e');
    }

    final resp = await http
        .get(
          Uri.parse('https://api.watchfooty.st/api/v1/match/$mid'),
          headers: {'User-Agent': _ua, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 45));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint('[WatchFooty] match HTTP ${resp.statusCode}');
      return const [];
    }
    final decoded = jsonDecode(resp.body);
    final match = decoded is List
        ? (decoded.isNotEmpty ? decoded.first : null)
        : decoded;
    if (match is! Map) return const [];
    final streams = match['streams'];
    if (streams is! List || streams.isEmpty) return const [];
    return [
      for (final s in streams)
        if (s is Map) Map<String, dynamic>.from(s),
    ];
  }

  @visibleForTesting
  static Map<String, dynamic>? parseSportsEmbedSlot(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !isSportsEmbedUrl(raw)) return null;
    final segs = uri.pathSegments;
    if (segs.length < 5 || segs.first != 'embed') return null;
    final matchId = segs[1];
    final slug = segs[2];
    final category = segs[3];
    final stream = segs[4];
    if (matchId.isEmpty || slug.isEmpty || category.isEmpty || stream.isEmpty) {
      return null;
    }
    return {
      'origin': uri.origin,
      'matchId': matchId,
      'slug': slug,
      'category': category,
      'stream': stream,
      'path': '$matchId/$slug/$category/$stream',
    };
  }

  /// Native Streamed resolve — bypasses flutter_js (no TextEncoder / fetch bridge).
  static Future<({String url, Map<String, String> headers})?> resolveStreamed({
    String embedUrl = '',
    String embedOrigin = _embedOrigin,
    String source = '',
    String matchId = '',
    String stream = '1',
  }) async {
    var embed = embedUrl.trim();
    if (embed.isEmpty && source.isNotEmpty && matchId.isNotEmpty) {
      final origin = embedOrigin.replaceAll(RegExp(r'/+$'), '');
      embed = '$origin/embed/$source/$matchId/$stream';
    }
    final slot = _parseEmbedSlot(embed, embedOrigin: embedOrigin);
    if (slot == null) return null;

    final slotSource = (slot['source'] ?? '').toString();
    if (slotSource == 'golf') {
      debugPrint(
        '[LiveGoatUnlock] golf embed has no native unlock — use Sniff mode',
      );
      return null;
    }

    final origin = (slot['origin'] ?? embedOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;

    try {
      final body = _encodeFetchBody(
        slotSource,
        (slot['id'] ?? '').toString(),
        (slot['stream'] ?? '1').toString(),
      );
      final referer = '$origin/embed/$path';
      final resp = await http
          .post(
            Uri.parse('$origin/fetch'),
            headers: {
              'Content-Type': 'application/octet-stream',
              'Origin': origin,
              'Referer': referer,
              'User-Agent': _ua,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('[LiveGoatUnlock] /fetch HTTP ${resp.statusCode}');
        return null;
      }
      final goat = resp.headers['goat'] ?? '';
      if (goat.isEmpty) {
        debugPrint('[LiveGoatUnlock] /fetch missing goat header');
        return null;
      }
      final bodyHex = resp.bodyBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final m3u8 = await unlock(slot: slot, goat: goat, bodyHex: bodyHex);
      if (m3u8 == null || m3u8.isEmpty) return null;

      final headers = playbackHeadersForSlot(slot);
      // Echo CDN (`/echo/stream/`) often 500s on Dart/mpv re-GET — don't hand
      // MediaKit a URL that cannot open natively.
      if (slotSource == 'echo') {
        if (!await _probePlayableM3u8(m3u8, headers)) {
          debugPrint(
            '[LiveGoatUnlock] echo GOAT m3u8 not native-playable (CDN probe)',
          );
          return null;
        }
      }
      return (url: m3u8, headers: headers);
    } catch (e) {
      debugPrint('[LiveGoatUnlock] native resolve failed: $e');
      return null;
    }
  }

  static Future<({String url, Map<String, String> headers})?> resolveEmbedIndia({
    required String embedUrl,
  }) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty) return null;
    if (isEpiEmbedsUrl(embed)) {
      final sniffed = await sniffEmbed(embedUrl: embed);
      if (sniffed != null && sniffed.isNotEmpty) {
        final origin = Uri.tryParse(embed)?.origin ?? '';
        return (
          url: sniffed,
          headers: {
            'Referer': embed,
            if (origin.isNotEmpty) 'Origin': origin,
            'User-Agent': _ua,
          },
        );
      }
      return null;
    }
    final slot = _parseEmbedIndiaSlot(embed);
    if (slot == null) {
      debugPrint('[LiveGasmUnlock] unparseable embedindia url: $embed');
      return null;
    }

    final origin = (slot['origin'] ?? _embedIndiaOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;

    try {
      final fetched = await _postEmbedIndiaFetch(
        origin: origin,
        path: path,
        gid: (slot['gid'] ?? '').toString(),
      ).timeout(const Duration(seconds: 20));
      if (fetched == null) return null;
      final m3u8 = await unlockGasm(
        slot: slot,
        island: fetched.island,
        bodyHex: fetched.bodyHex,
      );
      if (m3u8 == null || m3u8.isEmpty) {
        debugPrint('[LiveGasmUnlock] unlock returned empty path=$path');
        return null;
      }
      final headers = playbackHeadersForEmbedIndia(slot, embedUrl: embed);
      if (fetched.cookie != null && fetched.cookie!.isNotEmpty) {
        headers['Cookie'] = fetched.cookie!;
      }
      return (url: m3u8, headers: headers);
    } catch (e) {
      debugPrint('[LiveGasmUnlock] native resolve failed: $e');
      return null;
    }
  }

  /// Embed page warm-up + `/fetch` on one [HttpClient] jar — CDN tokens
  /// without WebView cookie harvest.
  static Future<({String island, String bodyHex, String? cookie})?>
  _postEmbedIndiaFetch({
    required String origin,
    required String path,
    required String gid,
  }) async {
    final referer = gid.isNotEmpty
        ? '$origin/embed/$path?gid=${Uri.encodeQueryComponent(gid)}'
        : '$origin/embed/$path';
    final client = HttpClient();
    client.userAgent = _ua;
    try {
      final embedUri = Uri.parse(referer);
      final embedReq = await client.getUrl(embedUri);
      embedReq.headers.set('Accept', 'text/html,application/xhtml+xml,*/*');
      final embedResp = await embedReq.close();
      if (embedResp.statusCode >= 400) {
        debugPrint(
          '[LiveGasmUnlock] embed warm HTTP ${embedResp.statusCode} path=$path',
        );
      }
      await consolidateHttpClientResponseBytes(embedResp);
      var cookies = _mergeSetCookieHeaders(null, embedResp.headers);

      final fetchUri = Uri.parse('$origin/fetch');
      final fetchReq = await client.postUrl(fetchUri);
      fetchReq.headers.set('Content-Type', 'application/octet-stream');
      fetchReq.headers.set('Origin', origin);
      fetchReq.headers.set('Referer', referer);
      fetchReq.headers.set('Accept', '*/*');
      if (cookies != null && cookies.isNotEmpty) {
        fetchReq.headers.set('Cookie', cookies);
      }
      fetchReq.add(_encodeEmbedIndiaFetchBody(path));
      final fetchResp = await fetchReq.close();
      if (fetchResp.statusCode < 200 || fetchResp.statusCode >= 300) {
        debugPrint(
          '[LiveGasmUnlock] /fetch HTTP ${fetchResp.statusCode} path=$path',
        );
        return null;
      }
      cookies = _mergeSetCookieHeaders(cookies, fetchResp.headers);
      final island = fetchResp.headers.value('island') ?? '';
      if (island.isEmpty) {
        debugPrint('[LiveGasmUnlock] /fetch missing island header path=$path');
        return null;
      }
      final bodyBytes = await consolidateHttpClientResponseBytes(fetchResp);
      final bodyHex = bodyBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return (island: island, bodyHex: bodyHex, cookie: cookies);
    } on TimeoutException {
      debugPrint('[LiveGasmUnlock] /fetch timeout path=$path');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String? _mergeSetCookieHeaders(
    String? existing,
    HttpHeaders headers,
  ) {
    final jar = <String, String>{};
    if (existing != null && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        jar[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim();
      }
    }
    headers.forEach((name, values) {
      if (name.toLowerCase() != 'set-cookie') return;
      for (final raw in values) {
        final first = raw.split(';').first.trim();
        final eq = first.indexOf('=');
        if (eq <= 0) continue;
        jar[first.substring(0, eq).trim()] = first.substring(eq + 1).trim();
      }
    });
    if (jar.isEmpty) return existing;
    return jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// PPV Engine: embed.st GOAT or embedindia.st GASM native unlock.
  static Future<({String url, Map<String, String> headers})?> resolvePpv({
    required String embedUrl,
  }) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty) {
      debugPrint('[LiveGasmUnlock] resolvePpv empty embed');
      return null;
    }
    if (isGasmJwEmbedUrl(embed)) {
      return resolveEmbedIndia(embedUrl: embed);
    }
    if (embed.contains('embed.st')) {
      return resolveStreamed(embedUrl: embed);
    }
    debugPrint('[LiveGasmUnlock] resolvePpv unsupported host: $embed');
    return null;
  }

  static Map<String, String> _embedHeaders(String? origin) {
    final o = (origin ?? _embedOrigin).replaceAll(RegExp(r'/+$'), '');
    return {'Referer': '$o/', 'Origin': o, 'User-Agent': _ua};
  }

  /// CDN Referer/Origin for GOAT-unlocked `strmd.st` playback.
  ///
  /// Each streamed.pk [source] validates differently — admin (`rtmp/stream`
  /// master playlists) must keep embed origin root; delta/echo media playlists
  /// use the embed page referer (streamed.pk Referer 403s on `strmd.st`).
  static Map<String, String> playbackHeadersForSlot(Map<String, dynamic> slot) {
    final origin = (slot['origin'] ?? _embedOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final source = (slot['source'] ?? '').toString().toLowerCase();
    final path = (slot['path'] ?? '').toString();
    switch (source) {
      case 'admin':
        return _embedHeaders(origin);
      case 'delta':
      case 'echo':
        if (path.isNotEmpty) {
          return {
            'Referer': '$origin/embed/$path',
            'Origin': origin,
            'User-Agent': _ua,
          };
        }
        return _embedHeaders(origin);
      default:
        if (path.isNotEmpty) {
          return {
            'Referer': '$origin/embed/$path',
            'Origin': origin,
            'User-Agent': _ua,
          };
        }
        return _embedHeaders(origin);
    }
  }

  /// CDN Referer for unlocked `*.indianservers.st` playlists.
  ///
  /// Use the embed **path** only — `?gid=` on Referer makes nginx 403 the
  /// master m3u8. Unlock `/fetch` still sends gid; playback must not.
  static Map<String, String> playbackHeadersForEmbedIndia(
    Map<String, dynamic> slot, {
    String? embedUrl,
  }) {
    final origin = (slot['origin'] ?? _embedIndiaOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = (slot['path'] ?? '').toString();
    final fromEmbed = (embedUrl ?? '').trim();
    String referer;
    if (fromEmbed.isNotEmpty) {
      final u = Uri.tryParse(fromEmbed);
      referer = (u != null && u.hasScheme && u.path.isNotEmpty)
          ? '$origin${u.path}'
          : (path.isNotEmpty ? '$origin/embed/$path' : '$origin/');
    } else if (path.isNotEmpty) {
      referer = '$origin/embed/$path';
    } else {
      referer = '$origin/';
    }
    return {'Referer': referer, 'Origin': origin, 'User-Agent': _ua};
  }

  /// Media playlists (`/delta/stream/`, `/echo/stream/`) ship `/m/…` segments
  /// with long signed query strings — open the catalog URL directly with
  /// [httpHeaders] instead of `/hls-proxy` rewrite. Admin master (`/rtmp/stream/`)
  /// stays on the proxy path.
  static bool preferDirectEnginePlayback(String m3u8Url) {
    final uri = Uri.tryParse(m3u8Url.trim());
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    final host = uri.host.toLowerCase();
    if (host.contains('wfty.st')) return true;
    // PPV embedindia CDN — signed `/secure/…/index.m3u8` segments 403 when
    // hls-proxy rewrites query strings; open direct with Referer/Cookie.
    if (host.contains('indianservers.st')) return true;
    if (host.contains('streamfree.top') && path.contains('/live/')) {
      return true;
    }
    return path.contains('/delta/stream/') ||
        path.contains('/echo/stream/') ||
        path.contains('/streamfree/stream/');
  }

  static Future<bool> _probePlayableM3u8(
    String url,
    Map<String, String> headers,
  ) async {
    final target = url.trim();
    if (target.isEmpty) return false;
    try {
      final resp = await http
          .get(Uri.parse(target), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode < 200 || resp.statusCode >= 400) {
        debugPrint(
          '[LiveGoatUnlock] m3u8 probe HTTP ${resp.statusCode} '
          '${Uri.tryParse(target)?.host ?? target}',
        );
        return false;
      }
      return resp.body.trimLeft().startsWith('#EXTM3U');
    } catch (e) {
      debugPrint('[LiveGoatUnlock] m3u8 probe failed: $e');
      return false;
    }
  }

  static Map<String, dynamic>? _parseEmbedSlot(
    String raw, {
    String embedOrigin = _embedOrigin,
  }) {
    final u = Uri.tryParse(raw.trim());
    if (u == null) return null;
    final em = RegExp(r'^/embed/([^/]+)/([^/]+)/(\d+)/?$').firstMatch(u.path);
    if (em != null) {
      final source = em.group(1)!;
      final id = em.group(2)!;
      final stream = em.group(3)!;
      return {
        'origin': u.origin,
        'source': source,
        'id': id,
        'stream': stream,
        'path': '$source/$id/$stream',
      };
    }
    final api = RegExp(r'^/api/stream/([^/]+)/([^/]+)/?$').firstMatch(u.path);
    if (api != null) {
      final origin = embedOrigin.replaceAll(RegExp(r'/+$'), '');
      final source = api.group(1)!;
      final id = api.group(2)!;
      final stream = u.queryParameters['stream'] ?? '1';
      return {
        'origin': origin,
        'source': source,
        'id': id,
        'stream': stream,
        'path': '$source/$id/$stream',
      };
    }
    return null;
  }

  static Map<String, dynamic>? _parseEmbedIndiaSlot(String raw) {
    final trimmed = raw.trim();
    if (!isEmbedIndiaUrl(trimmed)) return null;
    final u = Uri.tryParse(trimmed);
    if (u == null) return null;
    // Sports: /embed/{league}/{date}/{slug}
    // Events (UFC etc.): /embed/{slug} or /embed/{slug}/{variant}
    final em = RegExp(r'^/embed/(.+?)/?$').firstMatch(u.path);
    if (em == null) return null;
    final path = em.group(1)!.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty || path.contains('..')) return null;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final gid = u.queryParameters['gid'] ?? '';
    return {
      'origin': u.origin,
      'league': parts.length >= 3 ? parts[0] : '',
      'date': parts.length >= 3 ? parts[1] : '',
      'slug': parts.length >= 3 ? parts[2] : parts.last,
      'gid': gid,
      'path': path,
    };
  }

  static Uint8List _encodeFetchBody(String source, String id, String stream) {
    final out = BytesBuilder();
    void fieldStr(int field, String value) {
      final body = utf8.encode(value);
      out.addByte((field << 3) | 2);
      out.add(_varint(body.length));
      out.add(body);
    }

    fieldStr(1, source);
    fieldStr(2, id);
    fieldStr(3, stream);
    return out.toBytes();
  }

  static Uint8List _encodeEmbedIndiaFetchBody(String path) {
    final out = BytesBuilder();
    final body = utf8.encode(path);
    out.addByte((1 << 3) | 2);
    out.add(_varint(body.length));
    out.add(body);
    return out.toBytes();
  }

  static Uint8List _varint(int n) {
    final out = BytesBuilder();
    var v = n;
    while (v > 0x7f) {
      out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.addByte(v);
    return out.toBytes();
  }

  static Future<String?> unlock({
    required Map<String, dynamic> slot,
    required String goat,
    required String bodyHex,
  }) async {
    if (goat.isEmpty || bodyHex.isEmpty) return null;
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;
    final embedOrigin = (slot['origin'] ?? 'https://embed.st').toString();
    debugPrint(
      '[LiveGoatUnlock] path=$path goat=${goat.length} body=${bodyHex.length ~/ 2}B',
    );

    final node = await _findNodeBinary();
    if (node != null) {
      try {
        final dir = await _ensureGoatDir(node);
        final url = await _runNodeUnlock(
          node: node,
          dir: dir,
          slot: slot,
          goat: goat,
          bodyHex: bodyHex,
          embedOrigin: embedOrigin,
        );
        if (url != null && url.isNotEmpty) return url;
      } catch (e) {
        debugPrint('[LiveGoatUnlock] node unlock failed: $e');
      }
    } else {
      debugPrint('[LiveGoatUnlock] node not found — trying WebView unlock');
    }

    try {
      final url = await LiveGoatWebviewUnlock.instance.unlock(
        slot: slot,
        goat: goat,
        bodyHex: bodyHex,
        embedOrigin: embedOrigin,
      );
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      debugPrint('[LiveGoatUnlock] webview unlock failed: $e');
    }
    return null;
  }

  static Future<String?> unlockGasm({
    required Map<String, dynamic> slot,
    required String island,
    required String bodyHex,
  }) async {
    if (island.isEmpty || bodyHex.isEmpty) return null;
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;
    final embedOrigin = (slot['origin'] ?? _embedIndiaOrigin).toString();
    debugPrint(
      '[LiveGasmUnlock] path=$path island=${island.length} body=${bodyHex.length ~/ 2}B',
    );

    final node = await _findNodeBinary();
    if (node != null) {
      try {
        final dir = await _ensureGasmDir(node);
        final url = await _runGasmUnlock(
          node: node,
          dir: dir,
          slot: slot,
          island: island,
          bodyHex: bodyHex,
          embedOrigin: embedOrigin,
        );
        if (url != null && url.isNotEmpty) return url;
      } catch (e) {
        debugPrint('[LiveGasmUnlock] node unlock failed: $e');
      }
    } else {
      debugPrint('[LiveGasmUnlock] node not found — trying WebView unlock');
    }

    try {
      final url = await LiveGasmWebviewUnlock.instance.unlock(
        slot: slot,
        island: island,
        bodyHex: bodyHex,
        embedOrigin: embedOrigin,
      );
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      debugPrint('[LiveGasmUnlock] webview unlock failed: $e');
    }
    return null;
  }

  static Future<String?> sniffEmbed({
    required String embedUrl,
    String? referer,
  }) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty || !isEpiEmbedsUrl(embed)) return null;
    if (kIsWeb) return null;

    if (Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isAndroid ||
        Platform.isIOS) {
      final viaWebView = await _sniffEpiEmbedsWebView(
        embedUrl: embed,
        referer: (referer ?? embed).trim(),
      );
      if (viaWebView != null && viaWebView.isNotEmpty) return viaWebView;
    }

    final node = await _findNodeBinary();
    if (node == null) {
      debugPrint('[LiveSniffEmbed] node not found — sniff skipped');
      return null;
    }

    try {
      final dir = await _ensureGasmDir(node);
      return await _runSniffEmbed(
        node: node,
        dir: dir,
        embedUrl: embed,
        referer: (referer ?? embed).trim(),
      );
    } catch (e) {
      debugPrint('[LiveSniffEmbed] failed: $e');
      return null;
    }
  }

  static Future<String?> _sniffEpiEmbedsWebView({
    required String embedUrl,
    required String referer,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final completer = Completer<String?>();
    ForjaHeadlessInAppWebView? headless;

    Future<void> poll(InAppWebViewController controller) async {
      const js = '''
(function() {
  try {
    if (typeof jwplayer !== 'function') return '';
    var item = jwplayer().getPlaylistItem();
    if (!item) return '';
    if (item.file && /\.m3u8/i.test(item.file)) return item.file;
    var sources = item.sources;
    if (!Array.isArray(sources)) return '';
    for (var i = 0; i < sources.length; i++) {
      var u = sources[i] && sources[i].file;
      if (u && /\.m3u8/i.test(u)) return u;
    }
  } catch (_) {}
  return '';
})()
''';
      for (var i = 0; i < 40; i++) {
        if (completer.isCompleted) return;
        try {
          final raw = await controller.evaluateJavascript(source: js);
          final file = (raw ?? '').toString().trim();
          if (file.isNotEmpty && file.contains('.m3u8')) {
            if (!completer.isCompleted) completer.complete(file);
            return;
          }
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!completer.isCompleted) completer.complete(null);
    }

    headless = ForjaHeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(embedUrl),
        headers: {'Referer': referer, 'User-Agent': _ua},
      ),
      onWebViewCreated: (controller) {},
      onLoadStop: (controller, _) => unawaited(poll(controller)),
      onReceivedError: (_, __, ___) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    try {
      await headless!.run();
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('[LiveSniffEmbed] webview failed: $e');
      return null;
    } finally {
      await headless?.dispose();
    }
  }

  static Future<String?> _runSniffEmbed({
    required String node,
    required String dir,
    required String embedUrl,
    required String referer,
  }) async {
    final payload = jsonEncode({
      'embedUrl': embedUrl,
      'referer': referer,
    });
    final proc = await Process.start(
      node,
      ['sniff.mjs'],
      workingDirectory: dir,
      runInShell: false,
    );
    proc.stdin.write(payload);
    await proc.stdin.close();
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exit = await proc.exitCode.timeout(const Duration(seconds: 45));
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final raw = stdout.trim();
    if (exit != 0 || raw.isEmpty) {
      debugPrint('[LiveSniffEmbed] exit=$exit stdout=$raw stderr=$stderr');
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    if (decoded['ok'] == true) {
      return (decoded['url'] ?? '').toString().trim();
    }
    debugPrint('[LiveSniffEmbed] ${decoded['error']}');
    return null;
  }

  static Future<String?> _findNodeBinary() async {
    final candidates = <String>['node'];
    if (Platform.isWindows) {
      candidates.addAll([
        r'C:\Program Files\nodejs\node.exe',
        r'C:\Program Files (x86)\nodejs\node.exe',
      ]);
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        candidates.add('$local\\Programs\\node\\node.exe');
      }
    } else {
      candidates.addAll([
        '/opt/homebrew/bin/node',
        '/usr/local/bin/node',
      ]);
    }
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--version']);
        if (result.exitCode == 0) return c;
      } catch (_) {}
    }
    try {
      final lookup = Platform.isWindows ? 'where.exe' : 'which';
      final which = await Process.run(lookup, ['node']);
      if (which.exitCode == 0) {
        final path = which.stdout.toString().trim().split('\n').first.trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> _ensureGoatDir(String node) async {
    if (_cachedDir != null) {
      final ready = File('${_cachedDir!}/node_modules/happy-dom/package.json');
      if (await ready.exists()) return _cachedDir!;
    }
    _prepareFuture ??= _prepareGoatDir(node);
    await _prepareFuture;
    final dir = _cachedDir;
    if (dir == null) {
      throw StateError('GOAT unlock runtime failed to initialize');
    }
    return dir;
  }

  static Future<void> _prepareGoatDir(String node) async {
    final cached = _cachedDir;
    if (cached != null) {
      final ready = File('$cached/node_modules/happy-dom/package.json');
      if (await ready.exists()) return;
    }

    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/live-goat');
    await dir.create(recursive: true);

    await _writeAsset('$_assetRoot/unlock.mjs', File('${dir.path}/unlock.mjs'));
    await _writeAsset(
      '$_assetRoot/package.json',
      File('${dir.path}/package.json'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/lock.wasm',
      File('${dir.path}/vendor/lock.wasm'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/lock-esm.mjs',
      File('${dir.path}/vendor/lock-esm.mjs'),
    );

    final npm = await _findNpmBinary();
    if (npm == null) {
      throw StateError('npm not found (needed once for GOAT unlock deps)');
    }
    final install = await Process.run(
      npm,
      [
        'install',
        'happy-dom@17',
        'big-integer@1.6.52',
        '--no-fund',
        '--no-audit',
        '--prefer-offline',
      ],
      workingDirectory: dir.path,
    ).timeout(const Duration(minutes: 2));
    if (install.exitCode != 0) {
      throw StateError(
        'npm install failed: ${install.stderr.toString().trim()}',
      );
    }

    _cachedDir = dir.path;
  }

  static Future<String> _ensureGasmDir(String node) async {
    if (_cachedGasmDir != null) {
      final ready = File(
        '${_cachedGasmDir!}/node_modules/happy-dom/package.json',
      );
      if (await ready.exists()) {
        // Always refresh unlock + wasm — cache used to stick on a broken
        // script after first npm install.
        await _refreshGasmAssets(_cachedGasmDir!);
        return _cachedGasmDir!;
      }
    }
    _prepareGasmFuture ??= _prepareGasmDir(node);
    await _prepareGasmFuture;
    final dir = _cachedGasmDir;
    if (dir == null) {
      throw StateError('GASM unlock runtime failed to initialize');
    }
    return dir;
  }

  static Future<void> _refreshGasmAssets(String dir) async {
    await _writeAsset(
      '$_gasmAssetRoot/unlock.mjs',
      File('$dir/unlock.mjs'),
    );
    await _writeAsset(
      '$_gasmAssetRoot/sniff.mjs',
      File('$dir/sniff.mjs'),
    );
    // Ref pair (ppv-hls-stream-resolver) — offsets in unlock.mjs match this wasm.
    await _writeAsset(
      '$_gasmAssetRoot/vendor/gasm.wasm',
      File('$dir/vendor/gasm.wasm'),
    );
    await _writeAsset(
      '$_gasmAssetRoot/vendor/gasm.js',
      File('$dir/vendor/gasm.js'),
    );
    // Live embedindia pair (fallback).
    await _writeAsset(
      '$_gasmAssetRoot/vendor/gasm-live.wasm',
      File('$dir/vendor/gasm-live.wasm'),
    );
    await _writeAsset(
      '$_gasmAssetRoot/vendor/gasm-esm.mjs',
      File('$dir/vendor/gasm-esm.mjs'),
    );
  }

  static Future<void> _prepareGasmDir(String node) async {
    final support = await getApplicationSupportDirectory();
    // v3: pin happy-dom@20.11.6 and drop --prefer-offline (v2 hit ETARGET offline).
    final dir = Directory('${support.path}/live-gasm-v3');
    await dir.create(recursive: true);

    // Always overwrite unlock/wasm from the app bundle (script changes often).
    await _refreshGasmAssets(dir.path);
    await _writeAsset(
      '$_gasmAssetRoot/package.json',
      File('${dir.path}/package.json'),
    );

    final depsReady = File('${dir.path}/node_modules/happy-dom/package.json');
    if (!await depsReady.exists()) {
      final npm = await _findNpmBinary();
      if (npm == null) {
        throw StateError('npm not found (needed once for GASM unlock deps)');
      }
      // Clean lock from any half-failed prior install.
      final lock = File('${dir.path}/package-lock.json');
      if (await lock.exists()) await lock.delete();
      final install = await Process.run(
        npm,
        [
          'install',
          '--no-fund',
          '--no-audit',
          '--no-package-lock',
        ],
        workingDirectory: dir.path,
      ).timeout(const Duration(minutes: 3));
      if (install.exitCode != 0) {
        throw StateError(
          'npm install failed: ${install.stderr.toString().trim()}',
        );
      }
    }

    _cachedGasmDir = dir.path;
  }

  static Future<String?> _findNpmBinary() async {
    final candidates = <String>[Platform.isWindows ? 'npm.cmd' : 'npm'];
    if (Platform.isWindows) {
      candidates.addAll([
        r'C:\Program Files\nodejs\npm.cmd',
        r'C:\Program Files (x86)\nodejs\npm.cmd',
      ]);
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        candidates.add('$local\\Programs\\node\\npm.cmd');
      }
    } else {
      candidates.addAll([
        '/opt/homebrew/bin/npm',
        '/usr/local/bin/npm',
      ]);
    }
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--version']);
        if (result.exitCode == 0) return c;
      } catch (_) {}
    }
    try {
      final lookup = Platform.isWindows ? 'where.exe' : 'which';
      final which = await Process.run(lookup, [Platform.isWindows ? 'npm.cmd' : 'npm']);
      if (which.exitCode == 0) {
        final path = which.stdout.toString().trim().split('\n').first.trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeAsset(String assetPath, File out) async {
    await out.parent.create(recursive: true);
    final data = await rootBundle.load(assetPath);
    await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  static Future<String> _ensureSportsEmbedDir() async {
    if (_cachedSportsEmbedDir != null) {
      final ready = File(
        '${_cachedSportsEmbedDir!}/vendor/stream-lock.wasm',
      );
      if (await ready.exists()) {
        await _refreshSportsEmbedAssets(_cachedSportsEmbedDir!);
        return _cachedSportsEmbedDir!;
      }
    }
    _prepareSportsEmbedFuture ??= _prepareSportsEmbedDir();
    await _prepareSportsEmbedFuture;
    final dir = _cachedSportsEmbedDir;
    if (dir == null) {
      throw StateError('sportsembed unlock runtime failed to initialize');
    }
    return dir;
  }

  static Future<void> _refreshSportsEmbedAssets(String dir) async {
    await _writeAsset(
      '$_sportsEmbedAssetRoot/unlock.mjs',
      File('$dir/unlock.mjs'),
    );
    await _writeAsset(
      '$_sportsEmbedAssetRoot/vendor/stream-lock.wasm',
      File('$dir/vendor/stream-lock.wasm'),
    );
  }

  static Future<void> _prepareSportsEmbedDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/live-sportsembed');
    await dir.create(recursive: true);
    await _refreshSportsEmbedAssets(dir.path);
    _cachedSportsEmbedDir = dir.path;
  }

  static Future<String?> _runSportsEmbedUnlock({
    required String node,
    required String dir,
    required String embedUrl,
  }) async {
    final payload = jsonEncode({'embedUrl': embedUrl.trim()});
    final proc = await Process.start(
      node,
      ['unlock.mjs'],
      workingDirectory: dir,
      runInShell: false,
    );
    proc.stdin.write(payload);
    await proc.stdin.close();
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    late final int exit;
    try {
      exit = await proc.exitCode.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      proc.kill(ProcessSignal.sigkill);
      debugPrint('[LiveSportsEmbed] unlock.mjs timed out');
      return null;
    }
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final raw = stdout.trim();
    if (raw.isEmpty) {
      debugPrint('[LiveSportsEmbed] exit=$exit stderr=$stderr');
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    if (decoded['ok'] == true) {
      return (decoded['url'] ?? '').toString().trim();
    }
    debugPrint('[LiveSportsEmbed] ${decoded['error']}');
    return null;
  }

  static Future<String?> _runNodeUnlock({
    required String node,
    required String dir,
    required Map<String, dynamic> slot,
    required String goat,
    required String bodyHex,
    required String embedOrigin,
  }) async {
    final payload = jsonEncode({
      'slot': slot,
      'goat': goat,
      'bodyHex': bodyHex,
      'embedOrigin': embedOrigin,
    });
    final proc = await Process.start(
      node,
      ['unlock.mjs'],
      workingDirectory: dir,
      runInShell: false,
    );
    proc.stdin.write(payload);
    await proc.stdin.close();
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exit = await proc.exitCode.timeout(const Duration(seconds: 45));
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final raw = stdout.trim();
    if (exit != 0 || raw.isEmpty) {
      debugPrint('[LiveGoatUnlock] exit=$exit stdout=$raw stderr=$stderr');
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    if (decoded['ok'] == true) {
      return (decoded['url'] ?? '').toString().trim();
    }
    debugPrint('[LiveGoatUnlock] ${decoded['error']}');
    return null;
  }

  static Future<String?> _runGasmUnlock({
    required String node,
    required String dir,
    required Map<String, dynamic> slot,
    required String island,
    required String bodyHex,
    required String embedOrigin,
  }) async {
    final payload = jsonEncode({
      'slot': slot,
      'island': island,
      'bodyHex': bodyHex,
      'embedOrigin': embedOrigin,
    });
    final proc = await Process.start(
      node,
      ['unlock.mjs'],
      workingDirectory: dir,
      runInShell: false,
    );
    proc.stdin.write(payload);
    await proc.stdin.close();
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exit = await proc.exitCode.timeout(const Duration(seconds: 45));
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final raw = stdout.trim();
    if (exit != 0 || raw.isEmpty) {
      debugPrint('[LiveGasmUnlock] exit=$exit stdout=$raw stderr=$stderr');
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    if (decoded['ok'] == true) {
      return (decoded['url'] ?? '').toString().trim();
    }
    debugPrint('[LiveGasmUnlock] ${decoded['error']}');
    return null;
  }
}
