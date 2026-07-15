// kisskh.co stream extractor — headless WebView based.
//
// The site signs every Episode/{epId}.png and Sub/{epId} request with a
// `kkey` parameter generated client-side by heavily obfuscated JS. Rather
// than reverse the cipher in Dart, we let the page's own JS sign it for us
// by hooking `fetch`/`XHR` and capturing the parsed JSON response bodies.
//
// Flow:
//   1. Open the episode page in a fresh (no HTTP cache) headless WebView.
//   2. Inject hooks at AT_DOCUMENT_START for Episode/*.png + Sub/*.
//   3. Wait for KKH_VIDEO (soft-reload once if the SPA never requests it).

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:rust/rust.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/webview/forja_webview.dart';

class KissKhStream {
  final String url;
  final String type; // hls / mp4
  final List<Map<String, dynamic>> subtitles;
  final Map<String, String> headers;

  const KissKhStream({
    required this.url,
    required this.type,
    required this.headers,
    this.subtitles = const [],
  });
}

class KissKhExtractor {
  ForjaHeadlessInAppWebView? _web;
  InAppWebViewController? _controller;
  Completer<Map<String, dynamic>>? _apiCompleter;
  final List<Map<String, dynamic>> _subsBuffer = [];
  bool _cancelled = false;
  int _resolveGen = 0;
  Future<void> _resolveChain = Future<void>.value();

  /// Last resolve that registered itself for [cancelAllPending].
  static KissKhExtractor? _activeForCancel;

  /// Abort any in-flight KissKh WebView extract (player quit / title change).
  static Future<void> cancelAllPending() async {
    final active = _activeForCancel;
    if (active == null) return;
    await active.cancel();
  }

  static const _blockedHosts = <String>[
    'tickcounter.com',
    'google.com',
    'gstatic.com',
    'facebook.com',
    'twitter.com',
    'doubleclick.net',
  ];

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static Map<String, String> playbackHeaders(String baseUrl) => {
    'User-Agent': _userAgent,
    'Referer': '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/',
    'Origin': baseUrl.replaceFirst(RegExp(r'/$'), ''),
  };

  Future<KissKhStream?> resolve({
    required int dramaId,
    required String dramaTitle,
    required int episodeId,
    required double episodeNumber,
    void Function(String phase, String detail)? onProgress,
    Duration timeout = const Duration(seconds: 45),
    bool Function()? isCancelled,
  }) async {
    // Serialize resolves on this instance — overlapping WebViews cancel each
    // other and leave the UI stuck on "Waiting for stream key…".
    final previous = _resolveChain;
    final gate = Completer<void>();
    _resolveChain = gate.future;
    await cancel();
    await previous;
    _activeForCancel = this;
    try {
      return await _resolveBody(
        dramaId: dramaId,
        dramaTitle: dramaTitle,
        episodeId: episodeId,
        episodeNumber: episodeNumber,
        onProgress: onProgress,
        timeout: timeout,
        isCancelled: isCancelled,
      );
    } finally {
      if (identical(_activeForCancel, this)) {
        _activeForCancel = null;
      }
      if (!gate.isCompleted) gate.complete();
    }
  }

  static String _cacheBusted(String pageUrl) {
    final sep = pageUrl.contains('?') ? '&' : '?';
    return '$pageUrl${sep}_forja=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Map<String, String> _pageHeaders(String baseUrl) => {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/',
        'Upgrade-Insecure-Requests': '1',
        // Bypass intermediary HTTP caches for the SPA shell.
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

  Future<void> _purgeKissKhSiteData(String baseUrl) async {
    try {
      final manager = CookieManager.instance();
      await manager.deleteCookies(url: WebUri(baseUrl));
      await manager.deleteCookies(url: WebUri('$baseUrl/'));
    } catch (e) {
      debugPrint('[KissKhExtractor] cookie purge failed: $e');
    }
  }

  Future<void> _hardNavigate(
    InAppWebViewController ctrl,
    String pageUrl,
    String baseUrl,
  ) async {
    final url = _cacheBusted(pageUrl);
    if (kDebugMode) {
      debugPrint('[KissKhExtractor] hard navigate $url');
    }
    await _purgeKissKhSiteData(baseUrl);
    await ctrl.loadUrl(
      urlRequest: URLRequest(url: WebUri(url), headers: _pageHeaders(baseUrl)),
    );
  }

  Future<KissKhStream?> _resolveBody({
    required int dramaId,
    required String dramaTitle,
    required int episodeId,
    required double episodeNumber,
    void Function(String phase, String detail)? onProgress,
    required Duration timeout,
    bool Function()? isCancelled,
  }) async {
    final gen = ++_resolveGen;
    _cancelled = false;
    bool cancelled() =>
        _cancelled || gen != _resolveGen || (isCancelled?.call() ?? false);

    _apiCompleter = Completer<Map<String, dynamic>>();
    _subsBuffer.clear();
    late String baseUrl;
    late List<String> mirrorUrls;
    late String pageUrl;
    late String openUrl;
    var mirrorIndex = 0;
    var recoveryInFlight = false;
    Timer? recoveryTimer;
    Timer? nudgeTimer;

    try {
      onProgress?.call('init', 'Checking kisskh mirrors…');
      final endpoint = await KissKhService.resolveEndpoint();
      if (cancelled()) return null;
      baseUrl = endpoint.selected;
      mirrorUrls = endpoint.mirrors;
      pageUrl = KissKhService.episodePageUrl(
        baseUrl: baseUrl,
        dramaId: dramaId,
        title: dramaTitle,
        episodeId: episodeId,
        episodeNumber: episodeNumber,
      );
      openUrl = _cacheBusted(pageUrl);
      onProgress?.call('init', 'Opening kisskh page…');

      // Incognito + no HTTP cache alone is not enough on WKWebView: a plain
      // reload() can reuse the SPA shell / skip UserScript reinjection, so the
      // Episode/*.png kkey request never appears (stuck on "Waiting for stream
      // key…"). Cache-bust + hard loadUrl + kisskh cookie purge force a live
      // request.
      await _purgeKissKhSiteData(baseUrl);
      _web = ForjaHeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(openUrl),
          headers: _pageHeaders(baseUrl),
        ),
        initialSize: const Size(1280, 720),
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: _interceptScript(episodeId),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: _userAgent,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          // Fresh network every extract — do not reuse disk-cached Episode API.
          cacheEnabled: false,
          clearCache: true,
          incognito: true,
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onLoadStop: (controller, loadedUrl) async {
          if (gen != _resolveGen) return;
          onProgress?.call('loaded', 'Waiting for stream key…');
          if (kDebugMode) {
            debugPrint('[KissKhExtractor] page loaded: $loadedUrl');
          }
          try {
            await controller.evaluateJavascript(
              source:
                  'window.__kkhGotVideo = false;'
                  'window.__kkhInstallHooks && window.__kkhInstallHooks();'
                  'window.__kkhNudgePlay && window.__kkhNudgePlay(); true;',
            );
          } catch (e) {
            debugPrint('[KissKhExtractor] rehook failed: $e');
          }
        },
        onReceivedError: (controller, request, error) {
          if (gen != _resolveGen) return;
          debugPrint(
            '[KissKhExtractor] load error ${request.url}: '
            '${error.description} (${error.type})',
          );
        },
        onConsoleMessage: (_, msg) {
          if (gen != _resolveGen) return;
          var s = msg.message.trim();
          if (s.startsWith('"') && s.endsWith('"')) {
            s = s.substring(1, s.length - 1).replaceAll(r'\"', '"');
          }
          if (s.startsWith('KKH_VIDEO:')) {
            try {
              final raw = jsonDecode(s.substring('KKH_VIDEO:'.length));
              if (raw is! Map) return;
              final data = Map<String, dynamic>.from(raw);
              if (kDebugMode) {
                final keys = data.keys.take(8).join(',');
                debugPrint('[KissKhExtractor] video payload keys=[$keys]');
              }
              final c = _apiCompleter;
              if (c != null && !c.isCompleted) c.complete(data);
            } catch (e) {
              debugPrint('[KissKhExtractor] video parse failed: $e');
            }
            return;
          }
          if (s.startsWith('KKH_SUBS:')) {
            try {
              final data = jsonDecode(s.substring('KKH_SUBS:'.length));
              if (data is! List) return;
              for (final t in data) {
                if (t is! Map) continue;
                final src = (t['src'] ?? t['url'] ?? '').toString();
                if (src.isEmpty) continue;
                final label = (t['label'] ?? t['language'] ?? 'Unknown')
                    .toString();
                _subsBuffer.add({
                  'id': src,
                  'url': src,
                  'language': label,
                  'display': '$label - kisskh',
                  'sourceName': 'kisskh',
                });
              }
            } catch (e) {
              debugPrint('[KissKhExtractor] subs parse failed: $e');
            }
            return;
          }
          if (s.startsWith('KKH_LOG:')) {
            debugPrint('[KissKhExtractor JS] ${s.substring(8)}');
          }
        },
      );

      if (kDebugMode) {
        debugPrint('[KissKhExtractor] opening $openUrl');
      }

      await _web!.run();
      if (cancelled()) return null;

      // Do NOT block on onLoadStop — SPA can fire Episode/*.png before or
      // long after load-stop. Give each API-compatible mirror an 8s window,
      // then hard-navigate to the next mirror so a silent SPA cannot consume
      // the entire 45s extract timeout.
      recoveryTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
        if (cancelled() || recoveryInFlight) return;
        final c = _apiCompleter;
        if (c == null || c.isCompleted) return;
        final ctrl = _controller;
        if (ctrl == null || mirrorIndex + 1 >= mirrorUrls.length) return;

        recoveryInFlight = true;
        mirrorIndex++;
        baseUrl = mirrorUrls[mirrorIndex];
        pageUrl = KissKhService.episodePageUrl(
          baseUrl: baseUrl,
          dramaId: dramaId,
          title: dramaTitle,
          episodeId: episodeId,
          episodeNumber: episodeNumber,
        );
        debugPrint(
          '[KissKhExtractor] no Episode API after ${timer.tick * 8}s — '
          'trying mirror $baseUrl',
        );
        onProgress?.call('retry', 'Trying another kisskh mirror…');
        unawaited(
          _hardNavigate(ctrl, pageUrl, baseUrl).whenComplete(() {
            recoveryInFlight = false;
          }),
        );
      });

      nudgeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (cancelled()) return;
        final c = _apiCompleter;
        if (c == null || c.isCompleted) return;
        final ctrl = _controller;
        if (ctrl == null) return;
        unawaited(
          ctrl.evaluateJavascript(
            source: 'window.__kkhNudgePlay && window.__kkhNudgePlay(); true;',
          ),
        );
      });

      final api = await _apiCompleter!.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'No stream API response in ${timeout.inSeconds}s',
        ),
      );
      // Empty map is the cancel sentinel — not a real Episode payload.
      if (cancelled() || api.isEmpty) return null;
      try {
        await KissKhService.activateEndpoint(baseUrl);
      } catch (e) {
        debugPrint('[KissKhExtractor] mirror activation failed: $e');
      }

      // Brief grace so Sub/*.json can land after Video.
      if (_subsBuffer.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      if (cancelled()) return null;

      var streamUrl = _pickPlayableUrl(api);
      var streamType = _streamTypeFor(streamUrl);
      final referer = '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/';

      if (streamUrl == null) {
        final embed = _thirdPartyEmbedUrl(api);
        final rejected = (api['Video'] ?? api['video'] ?? '').toString().trim();
        if (rejected.isNotEmpty) {
          debugPrint(
            '[KissKhExtractor] Rejected Video URL: $rejected'
            '${embed != null ? ' — trying ThirdParty' : ''}',
          );
        }
        if (embed != null) {
          onProgress?.call('embed', 'Extracting third-party stream…');
          await _cleanup();
          final extracted = await StreamExtractor().extract(
            embed,
            referer: referer,
            timeout: const Duration(seconds: 30),
            isCancelled: () => cancelled(),
          );
          if (cancelled()) return null;
          if (extracted != null && extracted.url.isNotEmpty) {
            streamUrl = extracted.url;
            streamType = _streamTypeFor(streamUrl);
          }
        }
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        onProgress?.call('error', 'No playable stream in kisskh response');
        return null;
      }

      onProgress?.call('done', 'Stream ready');

      if (_subsBuffer.isNotEmpty) {
        onProgress?.call(
          'subs',
          'Decrypting ${_subsBuffer.length} subtitle track(s)…',
        );
        for (final s in _subsBuffer) {
          if (cancelled()) break;
          final url = (s['url'] ?? '').toString();
          if (url.isEmpty) continue;
          final localUri = await KissKhSubtitleDecryptor.fetchAndDecrypt(
            url: url,
            episodeId: episodeId,
            language: (s['language'] ?? 'sub').toString(),
            userAgent: _userAgent,
            referer: referer,
          );
          if (localUri != null) {
            s['url'] = localUri;
            s['id'] = localUri;
          }
        }
      }
      if (cancelled()) return null;

      return KissKhStream(
        url: streamUrl,
        type: streamType,
        subtitles: List<Map<String, dynamic>>.from(_subsBuffer),
        headers: playbackHeaders(baseUrl),
      );
    } catch (e) {
      if (cancelled()) return null;
      onProgress?.call('error', '$e');
      return null;
    } finally {
      recoveryTimer?.cancel();
      nudgeTimer?.cancel();
      if (gen == _resolveGen) {
        await _cleanup();
        _apiCompleter = null;
      }
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    _resolveGen++;
    final c = _apiCompleter;
    _apiCompleter = null;
    // Prefer complete(empty) over completeError — avoids unhandled
    // TimeoutException when the waiter was already torn down.
    if (c != null && !c.isCompleted) {
      c.complete(<String, dynamic>{});
    }
    await _cleanup();
  }

  Future<void> dispose() async {
    await cancel();
  }

  Future<void> _cleanup() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.evaluateJavascript(source: _stopMediaScript);
      } catch (e) {
        debugPrint('[KissKhExtractor] stop media error: $e');
      }
    }
    final w = _web;
    _web = null;
    if (w != null) {
      try {
        await w.dispose();
      } catch (e) {
        debugPrint('[KissKhExtractor] dispose error: $e');
      }
    }
  }

  static const _stopMediaScript = '''
(function () {
  document.querySelectorAll('video,audio').forEach(function (el) {
    try {
      el.pause();
      el.removeAttribute('src');
      el.load();
    } catch (e) {}
  });
})();
''';

  static String? _normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('//')) url = 'https:$url';
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url;
  }

  static bool _looksLikePlayableStream(String raw) {
    final url = _normalizeUrl(raw);
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (_blockedHosts.any(host.contains)) return false;
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.mpd') ||
        lower.contains('playlist') ||
        lower.contains('manifest') ||
        lower.contains('/master');
  }

  static String _streamTypeFor(String? url) {
    if (url != null && url.toLowerCase().contains('.m3u8')) return 'hls';
    return 'mp4';
  }

  static String? _pickPlayableUrl(Map<String, dynamic> api) {
    if (api.isEmpty) return null;
    for (final key in [
      'Video',
      'video',
      'ThirdParty',
      'thirdParty',
      'Thirdparty',
    ]) {
      final raw = api[key]?.toString().trim() ?? '';
      if (raw.isNotEmpty && _looksLikePlayableStream(raw)) {
        return _normalizeUrl(raw);
      }
    }
    String? found;
    void walk(dynamic node) {
      if (found != null) return;
      if (node is String) {
        if (_looksLikePlayableStream(node)) found = _normalizeUrl(node);
      } else if (node is Map) {
        for (final v in node.values) {
          walk(v);
          if (found != null) return;
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v);
          if (found != null) return;
        }
      }
    }

    walk(api);
    return found;
  }

  static String? _thirdPartyEmbedUrl(Map<String, dynamic> api) {
    for (final key in [
      'ThirdParty',
      'thirdParty',
      'Thirdparty',
      'thirdparty',
    ]) {
      final raw = api[key]?.toString().trim() ?? '';
      if (raw.isEmpty) continue;
      final url = _normalizeUrl(raw);
      if (url == null) continue;
      if (!_looksLikePlayableStream(url)) return url;
    }
    return null;
  }

  // ─── Build the in-page hook ─────────────────────────────────────
  String _interceptScript(int epId) {
    return '''
(function () {
  function log(msg) { console.log('KKH_LOG:' + msg); }
  function sendVideo(data) {
    window.__kkhGotVideo = true;
    console.log('KKH_VIDEO:' + JSON.stringify(data));
    try {
      document.querySelectorAll('video,audio').forEach(function (el) {
        try { el.muted = true; el.pause(); } catch (e) {}
      });
    } catch (e) {}
  }
  function sendSubs(data)  { console.log('KKH_SUBS:'  + JSON.stringify(data)); }

  function muteMedia(el) {
    try { el.muted = true; } catch (e) {}
  }
  if (!window.__kkhMediaGuard) {
    window.__kkhMediaGuard = true;
    document.addEventListener('play', function (e) {
      var t = e.target;
      if (!t || (t.tagName !== 'VIDEO' && t.tagName !== 'AUDIO')) return;
      muteMedia(t);
      if (window.__kkhGotVideo) {
        try { t.pause(); } catch (e) {}
      }
    }, true);
    new MutationObserver(function (mutations) {
      mutations.forEach(function (m) {
        m.addedNodes.forEach(function (node) {
          if (!node || node.nodeType !== 1) return;
          if (node.tagName === 'VIDEO' || node.tagName === 'AUDIO') muteMedia(node);
          node.querySelectorAll && node.querySelectorAll('video,audio').forEach(muteMedia);
        });
      });
    }).observe(document.documentElement, { childList: true, subtree: true });
  }

  function tryHandle(url, json) {
    try {
      if (!url) return;
      if (url.indexOf('/api/DramaList/Episode/') !== -1) {
        sendVideo(json || {});
      } else if (url.indexOf('/api/Sub/') !== -1) {
        if (Array.isArray(json)) sendSubs(json);
      }
    } catch (e) { log('handle err: ' + e); }
  }

  function wrapFetch(orig) {
    if (!orig || orig.__kkh) return orig;
    var wrapped = function () {
      var req = arguments[0];
      var url = (typeof req === 'string') ? req : (req && req.url) || '';
      if (url.indexOf('/api/DramaList/Episode/') !== -1 ||
          url.indexOf('/api/Sub/') !== -1) {
        log('fetch hit: ' + url);
      }
      return orig.apply(this, arguments).then(function (res) {
        try {
          if (url.indexOf('/api/DramaList/Episode/') !== -1 ||
              url.indexOf('/api/Sub/') !== -1) {
            res.clone().json().then(function (j) { tryHandle(url, j); })
              .catch(function () {});
          }
        } catch (e) {}
        return res;
      });
    };
    wrapped.__kkh = true;
    return wrapped;
  }

  function wrapXhr(OrigXhr) {
    if (!OrigXhr || OrigXhr.__kkh) return OrigXhr;
    function HookedXhr() {
      var x = new OrigXhr();
      var _url = '';
      var _open = x.open;
      x.open = function (m, u) {
        _url = u || '';
        return _open.apply(x, arguments);
      };
      x.addEventListener('load', function () {
        try {
          if (_url.indexOf('/api/DramaList/Episode/') !== -1 ||
              _url.indexOf('/api/Sub/') !== -1) {
            log('xhr hit: ' + _url);
            var j = null;
            try { j = JSON.parse(x.responseText); } catch (e) {}
            tryHandle(_url, j);
          }
        } catch (e) {}
      });
      return x;
    }
    HookedXhr.prototype = OrigXhr.prototype;
    HookedXhr.__kkh = true;
    HookedXhr.__kkhBase = OrigXhr;
    return HookedXhr;
  }

  function installHooks() {
    try {
      var fetchDesc = Object.getOwnPropertyDescriptor(window, 'fetch');
      var curFetch = (fetchDesc && fetchDesc.get) ? fetchDesc.get.call(window) : window.fetch;
      if (!curFetch || !curFetch.__kkh) {
        var liveFetch = wrapFetch(curFetch);
        Object.defineProperty(window, 'fetch', {
          configurable: true,
          enumerable: true,
          get: function () { return liveFetch; },
          set: function (v) {
            liveFetch = wrapFetch(typeof v === 'function' ? v : curFetch);
          }
        });
      }
    } catch (e) {
      try { window.fetch = wrapFetch(window.fetch); } catch (e2) {}
    }

    try {
      var xhrDesc = Object.getOwnPropertyDescriptor(window, 'XMLHttpRequest');
      var curXhr = (xhrDesc && xhrDesc.get) ? xhrDesc.get.call(window) : window.XMLHttpRequest;
      if (!curXhr || !curXhr.__kkh) {
        var liveXhr = wrapXhr(curXhr);
        Object.defineProperty(window, 'XMLHttpRequest', {
          configurable: true,
          enumerable: true,
          get: function () { return liveXhr; },
          set: function (v) {
            liveXhr = wrapXhr(v || curXhr);
          }
        });
      }
    } catch (e) {
      try { window.XMLHttpRequest = wrapXhr(window.XMLHttpRequest); } catch (e2) {}
    }
  }

  function nudgePlay() {
    if (window.__kkhGotVideo) return;
    try {
      document.querySelectorAll('video').forEach(function (v) {
        try {
          v.muted = true;
          var p = v.play();
          if (p && p.catch) p.catch(function () {});
        } catch (e) {}
      });
      var nodes = document.querySelectorAll(
        'button, [role="button"], .vjs-big-play-button, mat-icon'
      );
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        var label = ((el.getAttribute('aria-label') || '') + ' ' +
          (el.textContent || '') + ' ' + (el.getAttribute('data-mat-icon-name') || '')
        ).toLowerCase();
        if (label.indexOf('play') === -1) continue;
        try {
          (el.closest && el.closest('button')) ? el.closest('button').click() : el.click();
          log('nudge click play control');
        } catch (e) {}
        break;
      }
    } catch (e) {}
  }
  window.__kkhNudgePlay = nudgePlay;

  window.__kkhInstallHooks = installHooks;
  installHooks();
  if (!window.__kkhHookInterval) {
    var n = 0;
    window.__kkhHookInterval = setInterval(function () {
      installHooks();
      nudgePlay();
      if (++n > 60) {
        clearInterval(window.__kkhHookInterval);
        window.__kkhHookInterval = null;
      }
    }, 400);
  }
  log('intercept ready for ep $epId');
})();
''';
  }
}

extension KissKhStreamSources on KissKhStream {
  List<StreamSource> toSources({String label = 'kisskh'}) => [
    StreamSource(
      url: url,
      title: label,
      type: type,
      headers: Map<String, String>.from(headers),
    ),
  ];
}
