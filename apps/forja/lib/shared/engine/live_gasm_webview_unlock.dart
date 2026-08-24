import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_headless_in_app_webview.dart';
import 'package:path_provider/path_provider.dart';

/// Off-screen WebView host for embedindia.st GASM unlock when Node is
/// unavailable (Android / Android TV / iOS). Same crack as `gasm/unlock.mjs`.
///
/// Document [baseUrl] is `https://embedindia.st/` so gasm.wasm sees the real
/// embed origin. Scripts/wasm load from loopback with mixed-content allowed.
class LiveGasmWebviewUnlock {
  LiveGasmWebviewUnlock._();
  static final LiveGasmWebviewUnlock instance = LiveGasmWebviewUnlock._();

  static const _assetRoot = 'assets/plugins/live/gasm';
  static const _goatVendor = 'assets/plugins/live/goat/vendor';
  static const _embedOrigin = 'https://embedindia.st';
  static const _timeout = Duration(seconds: 45);

  HttpServer? _server;
  Directory? _dir;
  ForjaHeadlessInAppWebView? _hw;
  InAppWebViewController? _controller;
  Completer<bool>? _ready;
  Future<void>? _prepareFuture;
  Completer<Map<String, dynamic>>? _resultWait;
  Completer<void>? _pageLoad;
  Future<String?> _unlockChain = Future<String?>.value(null);
  int? _port;

  Future<String?> unlock({
    required Map<String, dynamic> slot,
    required String island,
    required String bodyHex,
    required String embedOrigin,
  }) {
    if (kIsWeb) return Future<String?>.value(null);
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return Future<String?>.value(null);
    }

    final done = Completer<String?>();
    _unlockChain = _unlockChain.then((_) async {
      String? url;
      try {
        url = await _unlockOnce(
          slot: slot,
          island: island,
          bodyHex: bodyHex,
          embedOrigin: embedOrigin,
        );
      } catch (e) {
        debugPrint('[LiveGasmWebview] unlock chain: $e');
        url = null;
      } finally {
        await _reloadRuntime();
      }
      if (!done.isCompleted) done.complete(url);
      return url;
    });
    return done.future;
  }

  Future<String?> _unlockOnce({
    required Map<String, dynamic> slot,
    required String island,
    required String bodyHex,
    required String embedOrigin,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final ok = await _ensureReady();
    if (!ok || _controller == null) return null;

    final wait = Completer<Map<String, dynamic>>();
    _resultWait = wait;

    try {
      final slotJson = jsonEncode(slot);
      String q(String s) => s
          .replaceAll(r'\', r'\\')
          .replaceAll("'", r"\'")
          .replaceAll('\n', r'\n')
          .replaceAll('\r', '');

      await _controller!.evaluateJavascript(
        source: '''
(async function(){
  try {
    if (typeof window.__gasmCrackJson !== 'function') {
      console.log('GASM_RESULT:' + JSON.stringify({ok:false,error:'gasm crack missing'}));
      return;
    }
    await window.__gasmCrackJson(
      '${q(slotJson)}',
      '${q(island)}',
      '${q(bodyHex)}',
      '${q(embedOrigin.isEmpty ? _embedOrigin : embedOrigin)}'
    );
  } catch (e) {
    console.log('GASM_RESULT:' + JSON.stringify({
      ok:false,
      error: String((e && (e.stack || e.message)) || e || 'evaluate failed')
    }));
  }
})();
''',
      );

      final result = await wait.future.timeout(_timeout);
      if (result['ok'] == true) {
        final url = (result['url'] ?? '').toString().trim();
        if (url.isEmpty) {
          debugPrint('[LiveGasmWebview] ok but empty url');
          return null;
        }
        debugPrint(
          '[LiveGasmWebview] ok ${url.length > 80 ? url.substring(0, 80) : url}…',
        );
        return url;
      }
      debugPrint('[LiveGasmWebview] crack failed: ${result['error']}');
      return null;
    } catch (e) {
      debugPrint('[LiveGasmWebview] unlock failed: $e');
      return null;
    } finally {
      if (identical(_resultWait, wait)) _resultWait = null;
    }
  }

  Future<void> _reloadRuntime() async {
    final c = _controller;
    final port = _port;
    if (c == null || port == null) return;
    try {
      await _syncCrackAsset();
      _pageLoad = Completer<void>();
      final html = _bootstrapHtml(port);
      await c.loadData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('$_embedOrigin/'),
      );
      await _pageLoad!.future.timeout(const Duration(seconds: 20));
      for (var i = 0; i < 50; i++) {
        final ready = await c.evaluateJavascript(
          source: 'window.__gasmReady === true',
        );
        if (ready == true || ready == 'true' || ready == 1) {
          debugPrint('[LiveGasmWebview] runtime reloaded');
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('[LiveGasmWebview] reload: crack not ready');
    } catch (e) {
      debugPrint('[LiveGasmWebview] reload failed: $e');
      await dispose();
    }
  }

  Future<void> _syncCrackAsset() async {
    final dir = _dir;
    if (dir == null) return;
    await _writeAsset(
      '$_assetRoot/webview/crack.js',
      File('${dir.path}/crack.js'),
    );
  }

  void _onConsole(String message) {
    debugPrint('[LiveGasmWebview/console] $message');
    const prefix = 'GASM_RESULT:';
    if (!message.startsWith(prefix)) return;
    final wait = _resultWait;
    if (wait == null || wait.isCompleted) return;
    try {
      final decoded = jsonDecode(message.substring(prefix.length));
      if (decoded is Map<String, dynamic>) {
        wait.complete(decoded);
      } else if (decoded is Map) {
        wait.complete(Map<String, dynamic>.from(decoded));
      } else {
        wait.complete({'ok': false, 'error': 'bad GASM_RESULT type'});
      }
    } catch (e) {
      wait.complete({'ok': false, 'error': 'bad GASM_RESULT json: $e'});
    }
  }

  String _bootstrapHtml(int port) {
    final base = 'http://127.0.0.1:$port';
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <base href="$_embedOrigin/" />
  <title>Forja GASM unlock</title>
</head>
<body>
  <div id="player"></div>
  <script>window.__GASM_ASSET_BASE = '$base';</script>
  <script src="$base/vendor/big-integer.min.js"></script>
  <script>
    (function () {
      var bi = typeof bigInt !== 'undefined' ? bigInt : window.bigInt;
      window.bigInt = bi;
      globalThis.require = function (name) {
        if (name === 'big-integer') return bi;
        return {};
      };
    })();
  </script>
  <script type="module" src="$base/crack.js?t=${DateTime.now().millisecondsSinceEpoch}"></script>
</body>
</html>
''';
  }

  Future<bool> _ensureReady() async {
    if (_ready != null) return _ready!.future;
    _ready = Completer<bool>();
    try {
      await (_prepareFuture ??= _prepareDir());
      final dir = _dir;
      if (dir == null) throw StateError('gasm webview dir missing');

      _server ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      unawaited(_serve(dir));

      _pageLoad = Completer<void>();
      final html = _bootstrapHtml(_port!);
      _hw = ForjaHeadlessInAppWebView(
        initialData: InAppWebViewInitialData(
          data: html,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('$_embedOrigin/'),
        ),
        initialSize: const Size(64, 64),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          isInspectable: kDebugMode,
          transparentBackground: true,
          supportZoom: false,
          disableHorizontalScroll: true,
          disableVerticalScroll: true,
          mediaPlaybackRequiresUserGesture: false,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          allowUniversalAccessFromFileURLs: true,
          allowFileAccessFromFileURLs: true,
        ),
        onLoadStop: (c, _) {
          _controller = c;
          final page = _pageLoad;
          if (page != null && !page.isCompleted) page.complete();
        },
        onConsoleMessage: (_, msg) => _onConsole(msg.message),
        onReceivedError: (_, req, err) {
          debugPrint(
            '[LiveGasmWebview] load error ${req.url} ${err.description}',
          );
        },
      );
      await _hw!.run();
      await _pageLoad!.future.timeout(const Duration(seconds: 20));

      for (var i = 0; i < 50; i++) {
        final ready = await _controller!.evaluateJavascript(
          source: 'window.__gasmReady === true',
        );
        if (ready == true || ready == 'true' || ready == 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final ready = await _controller!.evaluateJavascript(
        source: 'window.__gasmReady === true',
      );
      if (ready != true && ready != 'true' && ready != 1) {
        throw StateError('gasm crack not ready (mixed-content / module?)');
      }
      debugPrint('[LiveGasmWebview] runtime ready :$_port base=$_embedOrigin');
      _ready!.complete(true);
      return true;
    } catch (e, st) {
      debugPrint('[LiveGasmWebview] bootstrap failed: $e\n$st');
      if (!(_ready?.isCompleted ?? true)) _ready!.complete(false);
      await dispose();
      return false;
    }
  }

  Future<void> _serve(Directory dir) async {
    final server = _server;
    if (server == null) return;
    await for (final req in server) {
      try {
        final path = Uri.decodeComponent(req.uri.path);
        final rel = path.startsWith('/') ? path.substring(1) : path;
        final file = File(
          rel.isEmpty || rel == 'unlock.html'
              ? '${dir.path}/unlock.html'
              : '${dir.path}/$rel',
        );
        if (!await file.exists()) {
          req.response.statusCode = 404;
          await req.response.close();
          continue;
        }
        final name = file.path.toLowerCase();
        req.response.headers.contentType = ContentType.parse(
          name.endsWith('.html')
              ? 'text/html; charset=utf-8'
              : name.endsWith('.js') || name.endsWith('.mjs')
              ? 'text/javascript; charset=utf-8'
              : name.endsWith('.wasm')
              ? 'application/wasm'
              : 'application/octet-stream',
        );
        req.response.headers.set('Access-Control-Allow-Origin', '*');
        req.response.headers.set(
          'Cache-Control',
          'no-store, no-cache, must-revalidate',
        );
        await req.response.addStream(file.openRead());
        await req.response.close();
      } catch (e) {
        debugPrint('[LiveGasmWebview] serve error: $e');
        try {
          req.response.statusCode = 500;
          await req.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _prepareDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/live-gasm-webview');
    await dir.create(recursive: true);
    await Directory('${dir.path}/vendor').create(recursive: true);

    await _writeAsset(
      '$_assetRoot/webview/crack.js',
      File('${dir.path}/crack.js'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/gasm.wasm',
      File('${dir.path}/vendor/gasm.wasm'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/gasm.js',
      File('${dir.path}/vendor/gasm.js'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/gasm-live.wasm',
      File('${dir.path}/vendor/gasm-live.wasm'),
    );
    await _writeAsset(
      '$_goatVendor/big-integer.min.js',
      File('${dir.path}/vendor/big-integer.min.js'),
    );

    final gasmEsm = await rootBundle.loadString(
      '$_assetRoot/vendor/gasm-esm.mjs',
    );
    final browser = _stripNodePreamble(gasmEsm);
    await File('${dir.path}/vendor/gasm-browser.mjs').writeAsString(browser);

    _dir = dir;
  }

  static String _stripNodePreamble(String src) {
    final lines = src.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.contains("from 'node:module'") ||
          line.contains('from "node:module"') ||
          line.contains("from 'big-integer'") ||
          line.contains('from "big-integer"') ||
          line.contains('createRequire') ||
          line.contains('nodeRequire') ||
          line.trimLeft().startsWith('globalThis.require') ||
          line.trimLeft().startsWith('globalThis.__decryptLogs')) {
        i++;
        continue;
      }
      break;
    }
    return lines.sublist(i).join('\n');
  }

  static Future<void> _writeAsset(String assetPath, File out) async {
    await out.parent.create(recursive: true);
    final data = await rootBundle.load(assetPath);
    await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  Future<void> dispose() async {
    try {
      await _hw?.dispose();
    } catch (_) {}
    _hw = null;
    _controller = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = null;
    _ready = null;
    _prepareFuture = null;
    _resultWait = null;
    _pageLoad = null;
    _unlockChain = Future<String?>.value(null);
  }
}
