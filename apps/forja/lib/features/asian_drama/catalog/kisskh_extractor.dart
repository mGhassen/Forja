// kisskh.co stream extractor — headless WebView based.
//
// The site signs every Episode/{epId}.png and Sub/{epId} request with a
// `kkey` parameter generated client-side by heavily obfuscated JS. Rather
// than reverse the cipher in Dart, we let the page's own JS sign it for us
// by hooking `fetch` and capturing the parsed JSON response bodies.
//
// Flow:
//   1. Open https://kisskh.co/Drama/{slug}/Episode-{n}?id={dramaId}&ep={epId}
//      in a hidden HeadlessInAppWebView.
//   2. Inject a fetch hook at AT_DOCUMENT_START that:
//      - Detects calls to `/api/DramaList/Episode/{epId}.png`.
//      - Detects calls to `/api/Sub/{epId}`.
//      - Reads the response body and forwards both URL + JSON via
//        `console.log('KKH_VIDEO:...')` / `KKH_SUBS:...`.
//   3. Wait until either both arrive or a soft timeout (then ship video
//      alone — subs are optional).

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:rust/rust.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/webview/forja_webview_settings.dart';

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
  HeadlessInAppWebView? _web;
  InAppWebViewController? _controller;
  Completer<Map<String, dynamic>>? _apiCompleter;
  final List<Map<String, dynamic>> _subsBuffer = [];
  bool _cancelled = false;

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

  Future<KissKhStream?> resolve({
    required int dramaId,
    required String dramaTitle,
    required int episodeId,
    required double episodeNumber,
    void Function(String phase, String detail)? onProgress,
    Duration timeout = const Duration(seconds: 25),
    bool Function()? isCancelled,
  }) async {
    _cancelled = false;
    bool cancelled() => _cancelled || (isCancelled?.call() ?? false);
    onProgress?.call('init', 'Opening kisskh page…');

    final pageUrl = KissKhService.episodePageUrl(
      dramaId: dramaId,
      title: dramaTitle,
      episodeId: episodeId,
      episodeNumber: episodeNumber,
    );

    _apiCompleter = Completer<Map<String, dynamic>>();
    _subsBuffer.clear();

    try {
      _web = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: _interceptScript(episodeId),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        initialSettings: forjaWebViewSettings(
          InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: _userAgent,
          mediaPlaybackRequiresUserGesture: true,
          allowsInlineMediaPlayback: true,
          ),
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onLoadStop: (_, _) {
          onProgress?.call('loaded', 'Waiting for stream key…');
        },
        onConsoleMessage: (_, msg) {
          var s = msg.message.trim();
          if (s.startsWith('"') && s.endsWith('"')) {
            s = s.substring(1, s.length - 1).replaceAll(r'\"', '"');
          }
          if (s.startsWith('KKH_VIDEO:')) {
            try {
              final raw = jsonDecode(s.substring('KKH_VIDEO:'.length));
              if (raw is! Map) return;
              final data = Map<String, dynamic>.from(raw);
              if (_apiCompleter != null && !_apiCompleter!.isCompleted) {
                _apiCompleter!.complete(data);
              }
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

      await _web!.run();
      if (cancelled()) return null;

      final api = await _apiCompleter!.future.timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException('No stream API response in ${timeout.inSeconds}s'),
      );
      if (cancelled()) return null;

      // Brief grace window so subtitles (which often arrive slightly after
      // the video URL) can land in the same payload.
      await Future.any<void>([
        Future<void>.delayed(const Duration(milliseconds: 1200)),
        Future<void>.delayed(const Duration(milliseconds: 0))
            .then((_) => _subsBuffer.isEmpty
                ? Future<void>.delayed(const Duration(milliseconds: 1200))
                : Future<void>.value()),
      ]);
      if (cancelled()) return null;

      var streamUrl = _pickPlayableUrl(api);
      var streamType = _streamTypeFor(streamUrl);
      final referer = '${KissKhService.baseUrl}/';

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

      // ─── Decrypt subtitles ────────────────────────────────────────────
      if (_subsBuffer.isNotEmpty) {
        onProgress?.call('subs',
            'Decrypting ${_subsBuffer.length} subtitle track(s)…');
        for (final s in _subsBuffer) {
          if (cancelled()) break;
          final url = (s['url'] ?? '').toString();
          if (url.isEmpty) continue;
          final localUri = await KissKhSubtitleDecryptor.fetchAndDecrypt(
            url: url,
            episodeId: episodeId,
            language: (s['language'] ?? 'sub').toString(),
            userAgent: _userAgent,
            referer: '${KissKhService.baseUrl}/',
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
        headers: const {
          'User-Agent': _userAgent,
          'Referer': '${KissKhService.baseUrl}/',
          'Origin': KissKhService.baseUrl,
        },
      );
    } catch (e) {
      if (cancelled()) return null;
      onProgress?.call('error', '$e');
      return null;
    } finally {
      await _cleanup();
      _apiCompleter = null;
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    if (_apiCompleter != null && !_apiCompleter!.isCompleted) {
      _apiCompleter!.completeError(
        TimeoutException('KissKh extraction cancelled'),
      );
    }
    await _cleanup();
    _apiCompleter = null;
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
    for (final key in ['Video', 'video', 'ThirdParty', 'thirdParty', 'Thirdparty']) {
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
    for (final key in ['ThirdParty', 'thirdParty', 'Thirdparty', 'thirdparty']) {
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
  function sendVideo(data) { console.log('KKH_VIDEO:' + JSON.stringify(data)); }
  function sendSubs(data)  { console.log('KKH_SUBS:'  + JSON.stringify(data)); }

  function stopMedia(el) {
    try { el.muted = true; el.pause(); } catch (e) {}
  }
  document.addEventListener('play', function (e) {
    var t = e.target;
    if (t && (t.tagName === 'VIDEO' || t.tagName === 'AUDIO')) stopMedia(t);
  }, true);
  new MutationObserver(function (mutations) {
    mutations.forEach(function (m) {
      m.addedNodes.forEach(function (node) {
        if (!node || node.nodeType !== 1) return;
        if (node.tagName === 'VIDEO' || node.tagName === 'AUDIO') stopMedia(node);
        node.querySelectorAll && node.querySelectorAll('video,audio').forEach(stopMedia);
      });
    });
  }).observe(document.documentElement, { childList: true, subtree: true });

  log('intercept ready for ep $epId');

  function tryHandle(url, json) {
    try {
      if (!url) return;
      if (url.indexOf('/api/DramaList/Episode/') !== -1 &&
          url.indexOf('.png') !== -1) {
        sendVideo(json || {});
      } else if (url.indexOf('/api/Sub/') !== -1) {
        if (Array.isArray(json)) sendSubs(json);
      }
    } catch (e) { log('handle err: ' + e); }
  }

  // Hook fetch
  const origFetch = window.fetch;
  window.fetch = function () {
    const req = arguments[0];
    const url = (typeof req === 'string') ? req : (req && req.url) || '';
    return origFetch.apply(this, arguments).then(function (res) {
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

  // Hook XMLHttpRequest as well — Angular's HttpClient uses it.
  const OrigXhr = window.XMLHttpRequest;
  function HookedXhr() {
    const x = new OrigXhr();
    let _url = '';
    const _open = x.open;
    x.open = function (m, u) {
      _url = u || '';
      return _open.apply(x, arguments);
    };
    x.addEventListener('load', function () {
      try {
        if (_url.indexOf('/api/DramaList/Episode/') !== -1 ||
            _url.indexOf('/api/Sub/') !== -1) {
          let j = null;
          try { j = JSON.parse(x.responseText); } catch (e) {}
          tryHandle(_url, j);
        }
      } catch (e) {}
    });
    return x;
  }
  HookedXhr.prototype = OrigXhr.prototype;
  window.XMLHttpRequest = HookedXhr;
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
