import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Host bridge for `ctx.live.goatUnlock` / `ctx.live.gasmUnlock` — Node WASM decrypt.
class LiveGoatUnlock {
  LiveGoatUnlock._();

  static const _assetRoot = 'assets/plugins/live/goat';
  static const _gasmAssetRoot = 'assets/plugins/live/gasm';
  static const _embedOrigin = 'https://embed.st';
  static const _embedIndiaOrigin = 'https://embedindia.st';
  static const _watchfootyReferer = 'https://watchfooty.st/';
  static const _sportsEmbedHosts = ['sportsembed.su', 'spiderembed.top'];
  static const _goatSlotSources = {
    'admin',
    'delta',
    'echo',
    'golf',
    'ppv',
    'bravo',
  };
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? _cachedDir;
  static Future<void>? _prepareFuture;

  static String? _cachedGasmDir;
  static Future<void>? _prepareGasmFuture;

  static bool isSportsEmbedUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return _sportsEmbedHosts.any((h) => host == h || host.endsWith('.$h'));
  }

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

    final sniffed = await sniffEmbed(
      embedUrl: embed,
      referer: _watchfootyReferer,
    );
    if (sniffed == null || sniffed.isEmpty) return null;
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
    final slot = _parseEmbedIndiaSlot(embed);
    if (slot == null) return null;

    final origin = (slot['origin'] ?? _embedIndiaOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;

    try {
      final body = _encodeEmbedIndiaFetchBody(path);
      final gid = (slot['gid'] ?? '').toString();
      final referer = gid.isNotEmpty
          ? '$origin/embed/$path?gid=${Uri.encodeQueryComponent(gid)}'
          : '$origin/embed/$path';
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
        debugPrint('[LiveGasmUnlock] /fetch HTTP ${resp.statusCode}');
        return null;
      }
      final island = resp.headers['island'] ?? '';
      if (island.isEmpty) {
        debugPrint('[LiveGasmUnlock] /fetch missing island header');
        return null;
      }
      final bodyHex = resp.bodyBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final m3u8 = await unlockGasm(
        slot: slot,
        island: island,
        bodyHex: bodyHex,
      );
      if (m3u8 == null || m3u8.isEmpty) return null;
      return (
        url: m3u8,
        headers: playbackHeadersForEmbedIndia(slot, embedUrl: embed),
      );
    } catch (e) {
      debugPrint('[LiveGasmUnlock] native resolve failed: $e');
      return null;
    }
  }

  /// PPV Engine: embed.st GOAT or embedindia.st GASM native unlock.
  static Future<({String url, Map<String, String> headers})?> resolvePpv({
    required String embedUrl,
  }) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty) return null;
    if (isEmbedIndiaUrl(embed)) {
      return resolveEmbedIndia(embedUrl: embed);
    }
    if (embed.contains('embed.st')) {
      return resolveStreamed(embedUrl: embed);
    }
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

  static Map<String, String> playbackHeadersForEmbedIndia(
    Map<String, dynamic> slot, {
    String? embedUrl,
  }) {
    final origin = (slot['origin'] ?? _embedIndiaOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = (slot['path'] ?? '').toString();
    final gid = (slot['gid'] ?? '').toString();
    final referer = (embedUrl ?? '').trim().isNotEmpty
        ? embedUrl!.trim()
        : gid.isNotEmpty
        ? '$origin/embed/$path?gid=${Uri.encodeQueryComponent(gid)}'
        : '$origin/embed/$path';
    return {'Referer': referer, 'Origin': origin, 'User-Agent': _ua};
  }

  /// Media playlists (`/delta/stream/`, `/echo/stream/`) ship `/m/…` segments
  /// with long signed query strings — open the catalog URL directly with
  /// [httpHeaders] instead of `/hls-proxy` rewrite. Admin master (`/rtmp/stream/`)
  /// stays on the proxy path.
  static bool preferDirectEnginePlayback(String m3u8Url) {
    final path = (Uri.tryParse(m3u8Url.trim())?.path ?? '').toLowerCase();
    return path.contains('/delta/stream/') || path.contains('/echo/stream/');
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
          .timeout(const Duration(seconds: 10));
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
      debugPrint('[LiveGoatUnlock] node not found');
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
      debugPrint('[LiveGasmUnlock] node not found');
    }
    return null;
  }

  static Future<String?> sniffEmbed({
    required String embedUrl,
    String? referer,
  }) async {
    final url = embedUrl.trim();
    if (url.isEmpty) return null;
    final ref = (referer ?? url).trim();
    try {
      final extracted = await StreamExtractor().extract(
        url,
        referer: ref,
        iframeWrapperBaseUrl: ref.endsWith('/') ? ref : '$ref/',
        timeout: const Duration(seconds: 35),
      );
      final out = extracted?.url.trim() ?? '';
      return out.isEmpty ? null : out;
    } catch (e) {
      debugPrint('[LiveSniffEmbed] failed: $e');
      return null;
    }
  }

  static Future<String?> _findNodeBinary() async {
    const candidates = [
      'node',
      '/opt/homebrew/bin/node',
      '/usr/local/bin/node',
    ];
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--version']);
        if (result.exitCode == 0) return c;
      } catch (_) {}
    }
    try {
      final which = await Process.run('which', ['node']);
      if (which.exitCode == 0) {
        final path = which.stdout.toString().trim();
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
    const candidates = ['npm', '/opt/homebrew/bin/npm', '/usr/local/bin/npm'];
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--version']);
        if (result.exitCode == 0) return c;
      } catch (_) {}
    }
    try {
      final which = await Process.run('which', ['npm']);
      if (which.exitCode == 0) {
        final path = which.stdout.toString().trim();
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
