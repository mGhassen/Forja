import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/engine/live/live_goat_webview_unlock.dart';
import 'package:forja/shared/engine/live/live_gasm_webview_unlock.dart';
import 'package:forja/shared/engine/live/live_unlock_modules.dart';
import 'package:forja/shared/webview/forja_headless_in_app_webview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Opaque host crack runtime for live packs (`ctx.live.goatUnlock` /
/// `gasmUnlock` / `sportsEmbedUnlock` / sniff).
///
/// Packs own `/fetch` + resolve orchestration. This class runs Node/WebView
/// WASM decrypt (and sportsembed unlock) only — crack scripts come from the
/// live pack ([LiveUnlockModules]).
class LiveGoatUnlock {
  LiveGoatUnlock._();

  /// One GOAT/GASM crack at a time — parallel WebView/Node unlock crashes mobile.
  static Future<void> _nativeUnlockChain = Future<void>.value();

  static Future<T?> _enqueueNativeUnlock<T>(Future<T?> Function() run) {
    final done = Completer<T?>();
    _nativeUnlockChain = _nativeUnlockChain.then((_) async {
      T? value;
      try {
        value = await run();
      } catch (e, st) {
        debugPrint('[LiveGoatUnlock] native unlock chain: $e\n$st');
        value = null;
      } finally {
        if (!done.isCompleted) done.complete(value);
      }
    });
    return done.future;
  }

  static const _embedIndiaOrigin = 'https://embedindia.st';
  static const _sportsEmbedOrigin = 'https://sportsembed.su';
  static const _sportsEmbedHosts = ['sportsembed.su', 'spiderembed.top'];
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? _cachedDir;
  static Future<void>? _prepareFuture;

  static String? _cachedGasmDir;
  static Future<void>? _prepareGasmFuture;
  static bool _gasmAssetsWritten = false;

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

  static bool isEmbedIndiaUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return host == 'embedindia.st' || host.endsWith('.embedindia.st');
  }

  /// sportsembed.su client handshake → plaintext HLS URL.
  static Future<({String url, Map<String, String> headers})?> resolveSportsEmbed({
    required String embedUrl,
  }) {
    return _enqueueNativeUnlock(() async {
      return _resolveSportsEmbedImpl(embedUrl: embedUrl);
    });
  }

  static Future<({String url, Map<String, String> headers})?>
  _resolveSportsEmbedImpl({
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
      final headers = withWftyPlaybackReferer(
        result,
        playbackHeadersForSportsEmbed(slot),
      );
      // WatchFooty `lb*.wfty.st` is path-signed — Dart GET often 403s even when
      // MediaKit + sportsembed Referer (via /hls-proxy) can play.
      final host = Uri.tryParse(result)?.host.toLowerCase() ?? '';
      final skipProbe = host.contains('wfty.st');
      if (!skipProbe && !await _probePlayableM3u8(result, headers)) {
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

  static Map<String, String> playbackHeadersForSportsEmbed(
    Map<String, dynamic> slot,
  ) {
    final origin = (slot['origin'] ?? _sportsEmbedOrigin).toString().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = (slot['path'] ?? '').toString();
    // Same Referer as the sportsembed player page (hls.js in the browser).
    // Origin-root `https://sportsembed.su/` makes `wfty.st` 500 then serve a
    // PNG decoy playlist.
    if (path.isNotEmpty) {
      return {
        'Referer': '$origin/embed/$path',
        'Origin': origin,
        'User-Agent': _ua,
      };
    }
    return _sportsEmbedPlaybackHeaders(origin);
  }

  static Map<String, String> _sportsEmbedPlaybackHeaders(String? origin) {
    final o = (origin ?? _sportsEmbedOrigin).replaceAll(RegExp(r'/+$'), '');
    return {'Referer': '$o/', 'Origin': o, 'User-Agent': _ua};
  }

  /// `lb*.wfty.st/secure/{tok}/{cat}/{slug}/{n}/{matchId}/{exp}/playlist.m3u8`
  /// → sportsembed player Referer the site uses.
  static String? sportsEmbedRefererFromWftyPlaylist(String m3u8Url) {
    final uri = Uri.tryParse(m3u8Url.trim());
    if (uri == null || !uri.host.toLowerCase().contains('wfty.st')) {
      return null;
    }
    final segs = uri.pathSegments;
    if (segs.length < 8 || segs.first.toLowerCase() != 'secure') return null;
    final category = segs[2];
    final slug = segs[3];
    final stream = segs[4];
    final matchId = segs[5];
    if (category.isEmpty || slug.isEmpty || stream.isEmpty || matchId.isEmpty) {
      return null;
    }
    return '$_sportsEmbedOrigin/embed/$matchId/$slug/$category/$stream';
  }

  static Map<String, String> withWftyPlaybackReferer(
    String playUrl,
    Map<String, String> headers,
  ) {
    final reconstructed = sportsEmbedRefererFromWftyPlaylist(playUrl);
    if (reconstructed == null) return headers;
    final out = Map<String, String>.from(headers);
    String? take(String a, String b) => out[a] ?? out[b];
    final current = (take('Referer', 'referer') ?? '').trim();
    final weak = current.isEmpty ||
        current == '$_sportsEmbedOrigin/' ||
        current == _sportsEmbedOrigin ||
        current.contains('watchfooty.st');
    if (weak) {
      out.remove('referer');
      out['Referer'] = reconstructed;
      out['Origin'] ??= _sportsEmbedOrigin;
    }
    return out;
  }

  /// GET the playlist; true only when the body looks like HLS (`#EXTM3U`).
  /// Used to drop dead GOAT slots that still crack to a signed CDN URL.
  static Future<bool> probePlayableM3u8(
    String url,
    Map<String, String> headers,
  ) =>
      _probePlayableM3u8(url, headers);

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

  static Future<String?> unlock({
    required Map<String, dynamic> slot,
    required String goat,
    required String bodyHex,
  }) {
    return _enqueueNativeUnlock(
      () => _unlockImpl(slot: slot, goat: goat, bodyHex: bodyHex),
    );
  }

  static Future<String?> _unlockImpl({
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
  }) {
    return _enqueueNativeUnlock(
      () => _unlockGasmImpl(slot: slot, island: island, bodyHex: bodyHex),
    );
  }

  static Future<String?> _unlockGasmImpl({
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

    final gid = (slot['gid'] ?? '').toString();
    final origin = embedOrigin.replaceAll(RegExp(r'/+$'), '');
    final embedUrl = gid.isNotEmpty
        ? '$origin/embed/$path?gid=${Uri.encodeQueryComponent(gid)}'
        : '$origin/embed/$path';
    debugPrint(
      '[LiveGasmUnlock] wasm unlock empty — trying jw sniff path=$path',
    );
    final sniffed = await _sniffJwEmbedPlaylist(embedUrl: embedUrl);
    if (sniffed != null && sniffed.isNotEmpty) return sniffed;
    return null;
  }

  static Future<String?> sniffEmbed({
    required String embedUrl,
    String? referer,
  }) async {
    if (!isEpiEmbedsUrl(embedUrl) && !isEmbedIndiaUrl(embedUrl)) return null;
    return _sniffJwEmbedPlaylist(embedUrl: embedUrl, referer: referer);
  }

  /// JW embed playlist sniff (epiembeds / embedindia) when WASM memory scrape misses.
  static Future<String?> _sniffJwEmbedPlaylist({
    required String embedUrl,
    String? referer,
  }) async {
    final embed = embedUrl.trim();
    if (embed.isEmpty) return null;
    if (kIsWeb) return null;

    if (Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isAndroid ||
        Platform.isIOS) {
      final viaWebView = await _sniffJwEmbedWebView(
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

  static Future<String?> _sniffJwEmbedWebView({
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
    if (item.file && /.m3u8/i.test(item.file)) return item.file;
    var sources = item.sources;
    if (!Array.isArray(sources)) return '';
    for (var i = 0; i < sources.length; i++) {
      var u = sources[i] && sources[i].file;
      if (u && /.m3u8/i.test(u)) return u;
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
      onReceivedError: (_, _, _) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    try {
      await headless.run();
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('[LiveSniffEmbed] webview failed: $e');
      return null;
    } finally {
      await headless.dispose();
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
    proc.stdin.add(utf8.encode(payload));
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
      if (await ready.exists()) {
        // Always re-copy glue — hot reload can ship a new unlock.mjs/wasm
        // while this isolate still holds a warm goat dir.
        await _refreshGoatAssets(_cachedDir!);
        return _cachedDir!;
      }
    }
    _prepareFuture ??= _prepareGoatDir(node);
    await _prepareFuture;
    final dir = _cachedDir;
    if (dir == null) {
      throw StateError('GOAT unlock runtime failed to initialize');
    }
    return dir;
  }

  static Future<void> _refreshGoatAssets(String dir) async {
    await _writeModule(
      LiveUnlockModules.goat,
      'unlock.mjs',
      File('$dir/unlock.mjs'),
    );
    await _writeModule(
      LiveUnlockModules.goat,
      'vendor/lock.wasm',
      File('$dir/vendor/lock.wasm'),
    );
    await _writeModule(
      LiveUnlockModules.goat,
      'vendor/lock-esm.mjs',
      File('$dir/vendor/lock-esm.mjs'),
    );
    debugPrint('[LiveGoatUnlock] refreshed goat modules → $dir');
  }

  static Future<void> _prepareGoatDir(String node) async {
    final cached = _cachedDir;
    if (cached != null) {
      final ready = File('$cached/node_modules/happy-dom/package.json');
      if (await ready.exists()) {
        await _refreshGoatAssets(cached);
        return;
      }
    }

    final support = await getApplicationSupportDirectory();
    // v3: Node require("big-integer") shim lives in unlock.mjs + lock-esm
    // (v2 cache kept glue without the shim after live refresh).
    final dir = Directory('${support.path}/live-goat-v3');
    await dir.create(recursive: true);

    await _refreshGoatAssets(dir.path);
    await _writeModule(
      LiveUnlockModules.goat,
      'package.json',
      File('${dir.path}/package.json'),
    );

    final npm = await _findNpmBinary();
    if (npm == null) {
      throw StateError('npm not found (needed once for GOAT unlock deps)');
    }
    final install = await Process.run(
      npm,
      [
        'install',
        'happy-dom@20.11.6',
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
        if (!_gasmAssetsWritten) {
          await _refreshGasmAssets(_cachedGasmDir!);
        }
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
    await _writeModule(
      LiveUnlockModules.gasm,
      'unlock.mjs',
      File('$dir/unlock.mjs'),
    );
    await _writeModule(
      LiveUnlockModules.gasm,
      'sniff.mjs',
      File('$dir/sniff.mjs'),
    );
    // Ref pair (ppv-hls-stream-resolver) — offsets in unlock.mjs match this wasm.
    await _writeModule(
      LiveUnlockModules.gasm,
      'vendor/gasm.wasm',
      File('$dir/vendor/gasm.wasm'),
    );
    await _writeModule(
      LiveUnlockModules.gasm,
      'vendor/gasm.js',
      File('$dir/vendor/gasm.js'),
    );
    // Live embedindia pair (fallback).
    await _writeModule(
      LiveUnlockModules.gasm,
      'vendor/gasm-live.wasm',
      File('$dir/vendor/gasm-live.wasm'),
    );
    await _writeModule(
      LiveUnlockModules.gasm,
      'vendor/gasm-esm.mjs',
      File('$dir/vendor/gasm-esm.mjs'),
    );
    _gasmAssetsWritten = true;
  }

  static Future<void> _prepareGasmDir(String node) async {
    final support = await getApplicationSupportDirectory();
    // v3: pin happy-dom@20.11.6 and drop --prefer-offline (v2 hit ETARGET offline).
    final dir = Directory('${support.path}/live-gasm-v3');
    await dir.create(recursive: true);

    // Always overwrite unlock/wasm from the pack (script changes often).
    await _refreshGasmAssets(dir.path);
    await _writeModule(
      LiveUnlockModules.gasm,
      'package.json',
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

  static Future<void> _writeModule(
    String module,
    String relative,
    File out,
  ) =>
      LiveUnlockModules.writeTo(
        module: module,
        relative: relative,
        dest: out,
      );

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
    await _writeModule(
      LiveUnlockModules.sportsembed,
      'unlock.mjs',
      File('$dir/unlock.mjs'),
    );
    await _writeModule(
      LiveUnlockModules.sportsembed,
      'vendor/stream-lock.wasm',
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
    proc.stdin.add(utf8.encode(payload));
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
    proc.stdin.add(utf8.encode(payload));
    await proc.stdin.close();
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    late final int exit;
    try {
      exit = await proc.exitCode.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      proc.kill(ProcessSignal.sigkill);
      debugPrint('[LiveGoatUnlock] unlock.mjs timed out');
      return null;
    }
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
    proc.stdin.add(utf8.encode(payload));
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
