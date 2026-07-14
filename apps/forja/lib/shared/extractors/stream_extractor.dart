import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/extractors/amri_extractor.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/webview/forja_webview.dart';

class StreamExtractor {
  ForjaHeadlessInAppWebView? _headlessWebView;
  Completer<ExtractedMedia?>? _completer;
  Timer? _timeoutTimer;
  bool _cancelled = false;
  
  String? _capturedVideo;
  String? _capturedAudio;
  Map<String, String>? _capturedHeaders;
  
  // Track all detected video URLs to select best quality
  final List<String> _detectedVideoUrls = [];
  
  // Amri integration
  AmriExtractor? _amriExtractor;
  final TmdbService _tmdbService = TmdbService();
  String? _activeProviderId;

  String get _logTag =>
      _activeProviderId != null ? '[$_activeProviderId]' : '[StreamExtractor]';

  void _log(String message) => debugPrint('$_logTag $message');

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  // ── Helper: build default headers from a referer URL ──────────────────────
  Map<String, String> _buildHeaders(String referer) {
    final uri = Uri.tryParse(referer);
    final origin = uri != null ? '${uri.scheme}://${uri.host}' : referer;
    return {
      'User-Agent': _userAgent,
      'Referer': referer,
      'Origin': origin,
    };
  }

  Future<ExtractedMedia?> extractWithAmri({
    required String tmdbId,
    required bool isMovie,
    int? season,
    int? episode,
    bool Function()? isCancelled,
  }) async {
    try {
      // Initialize Amri extractor if needed
      _amriExtractor ??= AmriExtractor(onLog: (msg) => debugPrint('[Amri] $msg'));
      
      // Fetch title and year from TMDB
      String title;
      String year;
      
      if (isMovie) {
        final movieData = await _tmdbService.getMovieDetails(tmdbId);
        title = _tmdbService.getMovieTitle(movieData);
        year = _tmdbService.getReleaseYear(movieData);
      } else {
        final tvData = await _tmdbService.getTvShowDetails(tmdbId);
        title = _tmdbService.getTvShowTitle(tvData);
        year = _tmdbService.getReleaseYear(tvData);
      }
      
      // Extract sources
      final sourcesData = await _amriExtractor!.extractSources(
        tmdbId,
        title,
        year,
        season: season,
        episode: episode,
        isCancelled: isCancelled,
      );
      
      // Check for rate limit
      if (sourcesData['error'] == 'rate_limit') {
        debugPrint('[Amri] Rate limited, will fallback');
        return null;
      }
      
      // Parse sources
      final sourcesList = (sourcesData['sources'] as List?)
          ?.map((s) => StreamSource.fromJson(s as Map<String, dynamic>))
          .toList() ?? [];
      
      debugPrint('[Amri] Parsed ${sourcesList.length} sources');
      
      if (sourcesList.isEmpty) {
        debugPrint('[Amri] No sources found');
        return null;
      }
      
      debugPrint('[Amri] First source URL: ${sourcesList.first.url}');
      debugPrint('[Amri] First source title: ${sourcesList.first.title}');
      
      // Return first source as primary
      return ExtractedMedia(
        url: sourcesList.first.url,
        headers: {'User-Agent': _userAgent},
        sources: sourcesList,
        provider: 'amri',
      );
    } catch (e) {
      debugPrint('[Amri] Error: $e');
      return null;
    }
  }

  /// Stop an in-flight sniff and dispose the headless WebView.
  Future<void> cancel() async {
    _cancelled = true;
    await _cleanup();
    _activeProviderId = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
  }

  Future<ExtractedMedia?> extract(
    String url, {
    Duration timeout = const Duration(seconds: 60),
    String? referer,
    String? iframeWrapperBaseUrl,
    bool Function()? isCancelled,
    String? providerId,
  }) async {
    final sessionTag =
        providerId != null && providerId.trim().isNotEmpty ? providerId : null;
    // Dispose any prior WebView without dropping the new session tag.
    await _cleanup();
    _activeProviderId = sessionTag;
    if (isAndroidTvHeadlessWebViewBlocked) {
      _log('Headless WebView blocked on Android TV (use WebStreamr/Vidsrc)');
      _activeProviderId = null;
      return null;
    }
    _cancelled = false;

    bool cancelled() => _cancelled || (isCancelled?.call() ?? false);

    // Session / settings: wrap embed URL in an iframe so the page sees a
    // document.referrer (defeats some hosts that block direct loads).
    var wrapperBase = iframeWrapperBaseUrl;
    if (wrapperBase == null &&
        await SettingsService().getPlayerWebViewUseEmbed()) {
      wrapperBase = _originBaseUrl(url);
    }
    
    _completer = Completer<ExtractedMedia?>();
    _capturedVideo = null;
    _capturedAudio = null;
    _capturedHeaders = null;
    _detectedVideoUrls.clear();
    
    _timeoutTimer = Timer(timeout, () { 
      if (_completer != null && !_completer!.isCompleted) {
        if (cancelled()) {
          _cleanup();
          _completer?.complete(null);
          return;
        }
        // Select best quality from detected URLs before completing
        final playable = _detectedVideoUrls
            .where(StreamExtractor.isPlayableStreamUrl)
            .toList();
        if (playable.isNotEmpty) {
           _capturedVideo = _selectBestQuality(playable);
           _completeWithCaptured(url);
        } else if (_capturedVideo != null &&
            StreamExtractor.isPlayableStreamUrl(_capturedVideo!)) {
           _completeWithCaptured(url);
        } else {
          _log('Sniffing session timeout for: $url');
          _cleanup();
          _completer?.complete(null);
        }
      }
    });

    _log('RAW SNIFFER START: $url'
        '${referer != null ? ' (referer=$referer)' : ''}'
        '${wrapperBase != null ? ' (wrapper=$wrapperBase)' : ''}');

    // Build the headless webview. There are two modes:
    //  1) Direct: load `url` itself (with optional Referer/Origin headers).
    //  2) Wrapped: load a tiny HTML page via `loadData` whose baseUrl is
    //     `wrapperBase`. We then iframe `url` inside it. The iframe
    //     receives `document.referrer = wrapperBase`, defeating
    //     embed providers that block direct loads (megaplay/vidwish).
    if (wrapperBase != null) {
      _headlessWebView = ForjaHeadlessInAppWebView(
        initialData: InAppWebViewInitialData(
          data: _buildIframeWrapperHtml(url),
          baseUrl: WebUri(wrapperBase),
          historyUrl: WebUri(wrapperBase),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSize: const Size(1280, 720),
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: _getRawSpyJs(),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: _userAgent,
          mediaPlaybackRequiresUserGesture: false,
          cacheEnabled: true,
          clearCache: false,
          allowsInlineMediaPlayback: true,
          useOnLoadResource: true,
          iframeAllow: 'autoplay; fullscreen; encrypted-media',
          iframeAllowFullscreen: true,
        ),
        onLoadResource: _onLoadResource(url),
        onLoadStop: _onLoadStop(),
        onConsoleMessage: _onConsoleMessage(url),
      );
    } else {
      final initialReq = URLRequest(
        url: WebUri(url),
        headers: referer != null
            ? {
                'Referer': referer,
                'Origin': Uri.tryParse(referer)?.origin ?? referer,
              }
            : null,
      );
      _headlessWebView = ForjaHeadlessInAppWebView(
        initialUrlRequest: initialReq,
        initialSize: const Size(1280, 720),
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: _getRawSpyJs(),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: _userAgent,
          mediaPlaybackRequiresUserGesture: false,
          cacheEnabled: true,
          clearCache: false,
          allowsInlineMediaPlayback: true,
          useOnLoadResource: true,
          iframeAllow: 'autoplay; fullscreen; encrypted-media',
          iframeAllowFullscreen: true,
        ),
        onLoadResource: _onLoadResource(url),
        onLoadStop: _onLoadStop(),
        onConsoleMessage: _onConsoleMessage(url),
      );
    }

    try {
      await _headlessWebView?.run();
    } catch (e) {
      _log('Engine error: $e');
    }
    if (cancelled()) {
      await cancel();
      return null;
    }
    try {
      return await _completer?.future;
    } finally {
      if (_activeProviderId == sessionTag) {
        _activeProviderId = null;
      }
    }
  }

  // ── Wrapper helpers ──────────────────────────────────────────────────────

  void Function(InAppWebViewController, LoadedResource) _onLoadResource(String fallbackReferer) =>
      (controller, resource) {
        final rUrl = resource.url.toString();
        _log('Resource: $rUrl');
        _processUrl(rUrl, fallbackReferer);
      };

  void Function(InAppWebViewController, WebUri?) _onLoadStop() =>
      (controller, loadedUrl) async {
        _log('Page loaded: $loadedUrl');
        await controller.evaluateJavascript(source: _getRawSpyJs());
      };

  void Function(InAppWebViewController, ConsoleMessage) _onConsoleMessage(String fallbackReferer) =>
      (controller, consoleMessage) {
        final msg = consoleMessage.message;
        _log('Console: $msg');
        if (msg.contains('PT_EXTRACT:')) {
          String fullMsg =
              msg.substring(msg.indexOf('PT_EXTRACT:') + 'PT_EXTRACT:'.length).trim();
          String streamUrl = fullMsg;
          String? frameUrl;
          if (fullMsg.contains(' | FRAME: ')) {
            final parts = fullMsg.split(' | FRAME: ');
            streamUrl = parts[0];
            frameUrl = parts[1];
          }
          streamUrl = streamUrl.replaceAll('"', '').replaceAll("'", "").trim();
          streamUrl = streamUrl
              .replaceFirst('[FETCH]', '')
              .replaceFirst('[FETCH_BODY]', '')
              .replaceFirst('[XHR]', '')
              .replaceFirst('[POSTMESSAGE]', '')
              .replaceFirst('[ATTR_SRC]', '')
              .replaceFirst('[MUTATION_SRC]', '')
              .replaceFirst('[ATTR_DATA-SRC]', '')
              .replaceFirst('[VIDEO_SRC]', '')
              .replaceFirst('[SOURCE_SRC]', '')
              .replaceFirst('[MEDIA_PLAY]', '')
              .trim();
          _processUrl(streamUrl, frameUrl ?? fallbackReferer);
        }
      };

  String _buildIframeWrapperHtml(String embedUrl) {
    // Minimal page: full-bleed iframe with autoplay + fullscreen perms.
    // Because we load this via `loadData(baseUrl: …)`, the iframe's
    // `document.referrer` and `window.parent.location.origin` reflect the
    // base URL (e.g. https://www.enma.lol/), which is what megaplay/vidwish
    // gate on. No HTML-escaping needed: the URL was built by us.
    return '''<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="referrer" content="unsafe-url">
<title>player</title>
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}iframe{border:0;width:100%;height:100%;display:block}</style>
</head><body>
<iframe id="p" src="$embedUrl" allow="autoplay; fullscreen; encrypted-media" allowfullscreen referrerpolicy="unsafe-url"></iframe>
</body></html>''';
  }

  /// Origin root for iframe-wrapper baseUrl (e.g. `https://vidfast.vc/`).
  static String? _originBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return '${uri.scheme}://${uri.host}/';
  }


  void _processUrl(String rUrl, String referer) {
    if (!isPlayableStreamUrl(rUrl)) return;

       // Check audio only in the URL path (not query params)
       final pathOnly = Uri.tryParse(rUrl)?.path ?? rUrl;
       if (pathOnly.contains('/audio/') || pathOnly.contains('audio_')) {
          _log('AUDIO DETECTED: $rUrl');
          _capturedAudio = rUrl;
          // ✅ FIX: was `headers` (undefined getter) — now builds the map correctly
          _capturedHeaders ??= _buildHeaders(referer);
       } else {
          _log('VIDEO/STREAM DETECTED: $rUrl');
          
          // Add to detected URLs list for quality selection
          if (!_detectedVideoUrls.contains(rUrl)) {
            _detectedVideoUrls.add(rUrl);
          }
          
          // Update captured video with best quality so far
          _capturedVideo = _selectBestQuality(_detectedVideoUrls);
          // ✅ FIX: was `headers` (undefined getter) — now builds the map correctly
          _capturedHeaders ??= _buildHeaders(referer);
       }

       if (_capturedVideo == null) return;

       // SPA embeds (AnyEmbed/SmashyStream, Anitaro) load streams after boot —
       // do not complete on weak hits like PWA manifest links.
       if (_shouldDeferEarlyComplete(referer)) {
         if (isStrongStreamUrl(_capturedVideo!)) {
           _completeWithCaptured(referer);
         }
         return;
       }

       if (_capturedAudio != null || !referer.contains('anitaro')) {
          _completeWithCaptured(referer);
       }
  }

  /// Whether a sniffed URL is a real media stream (not PWA manifest, SW, etc.).
  static bool isPlayableStreamUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    // Placeholders / relative ATTR_SRC (e.g. vidrock `/demo-video.mp4`).
    if (isUnplayableCachedStreamUrl(trimmed)) return false;

    final lower = trimmed.toLowerCase();
    if (lower.contains('google')) return false;
    if (lower.contains('.webmanifest')) return false;
    if (lower.endsWith('/manifest.webmanifest')) return false;
    if (lower.contains('manifest.json') && !lower.contains('.m3u8')) {
      return false;
    }

    if (lower.contains('.m3u8')) return true;
    if (lower.contains('.mpd')) return true;
    if (lower.contains('.mp4') && !lower.contains('googlevideo.com')) {
      return true;
    }
    if (lower.contains('playlist') && !lower.contains('webmanifest')) {
      return true;
    }
    if (lower.contains('master')) return true;

    final path = Uri.tryParse(trimmed)?.path.toLowerCase() ?? lower;
    if (path.contains('manifest.m3u8') || path.contains('manifest.mpd')) {
      return true;
    }
    if (path.endsWith('/manifest') && !path.contains('webmanifest')) {
      return true;
    }

    if (lower.contains('heistotron.uk/p/')) return true;
    if (lower.contains('okcdn.ru/') &&
        lower.contains('type=') &&
        !lower.contains('bytes=') &&
        !lower.contains('appId=')) {
      return true;
    }
    if (lower.contains('vkuser.net/') &&
        lower.contains('type=') &&
        !lower.contains('bytes=') &&
        !lower.contains('appId=')) {
      return true;
    }
    return false;
  }

  static bool isStrongStreamUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mpd') ||
        (lower.contains('.mp4') && !lower.contains('googlevideo.com')) ||
        (lower.contains('playlist') && !lower.contains('webmanifest'));
  }

  bool _shouldDeferEarlyComplete(String referer) {
    final r = referer.toLowerCase();
    return r.contains('anitaro') ||
        r.contains('anyembed.xyz') ||
        r.contains('smashystream.com') ||
        r.contains('player.videasy.to') ||
        r.contains('vidlink.pro');
  }

  String _selectBestQuality(List<String> urls) {
    final playable =
        urls.where(StreamExtractor.isPlayableStreamUrl).toList();
    if (playable.isEmpty) return urls.isNotEmpty ? urls.first : '';

    // Quality priority: 4K > 2160p > 1440p > 1080p > 720p > 480p > 360p
    final qualityOrder = ['4K', '2160p', '1440p', '1080p', '720p', '480p', '360p'];
    
    for (final quality in qualityOrder) {
      final match = playable.firstWhere(
        (url) => url.toLowerCase().contains('quality=$quality'.toLowerCase()),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        _log('Selected quality: $quality from ${playable.length} options');
        return match;
      }
    }
    
    // Prefer HLS/DASH over progressive when multiple hits exist.
    final hls = playable.where((u) => u.toLowerCase().contains('.m3u8'));
    if (hls.isNotEmpty) return hls.first;

    return playable.first;
  }

  void _completeWithCaptured(String referer) {
    if (_cancelled) return;
    if (_completer != null && !_completer!.isCompleted) {
      final headers = _capturedHeaders ?? _buildHeaders(referer);
      _completer!.complete(ExtractedMedia(
        url: _capturedVideo!,
        audioUrl: _capturedAudio,
        headers: headers,
        sources: _buildCapturedSources(headers),
      ));
      _cleanup();
    }
  }

  List<StreamSource> _buildCapturedSources(Map<String, String> headers) {
    final urls = _detectedVideoUrls.isNotEmpty
        ? List<String>.from(_detectedVideoUrls)
        : (_capturedVideo != null ? [_capturedVideo!] : const <String>[]);
    return urls.map((url) {
      final lower = url.toLowerCase();
      final type = lower.contains('.m3u8')
          ? 'hls'
          : lower.contains('.mpd')
              ? 'dash'
              : 'mp4';
      final title = lower.contains('h265') || lower.contains('hevc')
          ? 'HEVC'
          : lower.contains('1080')
              ? '1080p'
              : lower.contains('720')
                  ? '720p'
                  : 'Stream';
      return StreamSource(
        url: url,
        title: title,
        type: type,
        headers: headers,
      );
    }).toList();
  }

  String _getRawSpyJs() {
    return """
    (function() {
      if (window.pt_raw_injected) return;
      window.pt_raw_injected = true;
      
      const log = (type, url) => {
        if (!url || typeof url !== 'string' || url.startsWith('data:')) return;
        console.log('PT_EXTRACT: [' + type + '] ' + url + ' | FRAME: ' + window.location.href);
      };

      console.log('PT_LOG: Sniffer Active on ' + window.location.href);

      // 1. Popup Blocking
      window.open = function() { return null; };
      window.alert = function() { return true; };

      // 2. Sniff Fetch (log m3u8 URLs inside AnyEmbed stream API JSON)
      const originalFetch = window.fetch;
      window.fetch = async function(...args) {
        const url = args[0] instanceof Request ? args[0].url : String(args[0]);
        log('FETCH', url);
        const res = await originalFetch.apply(this, args);
        if (typeof url === 'string' && (url.includes('/api/v1/stream') || url.includes('/api/proxy'))) {
          try {
            const clone = res.clone();
            const text = await clone.text();
            const m = text.match(/https?:\\/\\/[^"'\\s]+\\.m3u8[^"'\\s]*/i);
            if (m) log('FETCH_BODY', m[0]);
          } catch (e) {}
        }
        return res;
      };

      // 3. Sniff XHR
      const originalXHROpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(method, url) {
        log('XHR', url);
        return originalXHROpen.apply(this, arguments);
      };

      // 4. Sniff Worker
      const OriginalWorker = window.Worker;
      window.Worker = function(scriptURL, options) {
        log('WORKER', scriptURL);
        return new OriginalWorker(scriptURL, options);
      };

      // 5. Sniff postMessage
      const originalPostMessage = window.postMessage;
      window.postMessage = function(message, targetOrigin, transfer) {
        if (typeof message === 'string') {
           log('POSTMESSAGE', message);
        }
        return originalPostMessage.apply(this, arguments);
      };

      // 6. Sniff URL.createObjectURL
      const originalCreateObjectURL = URL.createObjectURL;
      URL.createObjectURL = function(obj) {
        const url = originalCreateObjectURL.apply(this, arguments);
        log('BLOB_URL', url);
        return url;
      };

      // 7. Hook setAttribute
      const originalSetAttribute = Element.prototype.setAttribute;
      Element.prototype.setAttribute = function(name, value) {
        if (name === 'src' || name === 'data-src') {
           log('ATTR_' + name.toUpperCase(), value);
        }
        return originalSetAttribute.apply(this, arguments);
      };

      // 8. MutationObserver for dynamic elements
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach((node) => {
            if (node.tagName === 'VIDEO' || node.tagName === 'SOURCE' || node.tagName === 'IFRAME') {
              if (node.src) log('MUTATION_SRC', node.src);
            }
          });
          if (mutation.type === 'attributes' && (mutation.attributeName === 'src' || mutation.attributeName === 'data-src')) {
            log('MUTATION_ATTR', mutation.target.getAttribute(mutation.attributeName));
          }
        });
      });
      observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true });

      // 9. Hook Media Element Methods
      const originalPlay = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function() {
        if (this.src) log('MEDIA_PLAY', this.src);
        return originalPlay.apply(this, arguments);
      };

      // 10. Auto-interact to trigger playback
      const interact = () => {
        // Click center of screen (Spam click 3 times)
        const centerX = window.innerWidth / 2;
        const centerY = window.innerHeight / 2;
        
        for(let i=0; i<3; i++) {
          const el = document.elementFromPoint(centerX, centerY);
          if (el) {
            el.click();
            el.dispatchEvent(new MouseEvent('click', { view: window, bubbles: true, cancelable: true, clientX: centerX, clientY: centerY }));
          }
        }

        const selectors = [
          '.play-icon-main', '.jw-icon-display', '.jw-display-icon-container', '.jw-icon-playback', 
          '.jw-button-color', '#play-button', '.play-button', '.v-play-button',
          '.vjs-big-play-button', '[class*="play" i]', '[id*="play" i]',
          '.play-icon', '.play_icon', '.play-btn', '.play_btn',
          '.click_to_play', '.overlay', '#player_overlay', 'button', 'a'
        ];
        
        selectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(btn => {
             const rect = btn.getBoundingClientRect();
             if (rect.width > 0 && rect.height > 0) {
                const text = (btn.innerText || btn.textContent || '').toLowerCase();
                const id = (btn.id || '').toLowerCase();
                const cls = (btn.className || '').toString().toLowerCase();
                
                if (text.includes('play') || id.includes('play') || cls.includes('play') || cls.includes('overlay')) {
                   btn.click();
                }
             }
          });
        });

        document.querySelectorAll('video').forEach(v => {
          if (v.paused) v.play().catch(() => v.click());
          if (v.src) log('VIDEO_SRC', v.src);
        });
      };
      
      setTimeout(() => {
        interact();
        setInterval(interact, 800);
      }, 1000);
    })();
    """;
  }

  Future<void> _cleanup() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    
    if (_headlessWebView != null) {
      _log('Disposing headless WebView...');
      try {
        final controller = _headlessWebView?.webViewController;
        if (controller != null) {
          await controller.evaluateJavascript(source: '''
            document.querySelectorAll('video,audio').forEach(function(m) {
              try { m.pause(); m.removeAttribute('src'); m.load(); } catch(e) {}
            });
          ''');
        }
        await _headlessWebView?.dispose();
      } catch (e) {
        _log('Error during disposal: $e');
      }
      _headlessWebView = null;
    }
  }

  Future<void> dispose() async {
    await cancel();
    
    // Dispose Amri extractor
    await _amriExtractor?.dispose();
    _amriExtractor = null;
  }
}