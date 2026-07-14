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
  bool _completing = false;

  String? _capturedVideo;
  String? _capturedAudio;
  Map<String, String>? _capturedHeaders;
  /// Canonical embed URL passed to [extract] — preferred Referer for CDN opens.
  String? _originalEmbedUrl;

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
    _completing = false;
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
    bool forceDirect = false,
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
    var wrapperBase = forceDirect ? null : iframeWrapperBaseUrl;
    if (!forceDirect &&
        wrapperBase == null &&
        await SettingsService().getPlayerWebViewUseEmbed()) {
      wrapperBase = _originBaseUrl(url);
    }
    
    _completer = Completer<ExtractedMedia?>();
    _capturedVideo = null;
    _capturedAudio = null;
    _capturedHeaders = null;
    _originalEmbedUrl = url;
    _completing = false;
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
              .replaceFirst('[XHR_BODY]', '')
              .replaceFirst('[POSTMESSAGE]', '')
              .replaceFirst('[ATTR_SRC]', '')
              .replaceFirst('[MUTATION_SRC]', '')
              .replaceFirst('[MUTATION_ATTR]', '')
              .replaceFirst('[ATTR_DATA-SRC]', '')
              .replaceFirst('[VIDEO_SRC]', '')
              .replaceFirst('[SOURCE_SRC]', '')
              .replaceFirst('[MEDIA_PLAY]', '')
              .replaceFirst('[BLOB_URL]', '')
              .replaceFirst('[WORKER]', '')
              .replaceFirst('[SERVER_CLICK]', '')
              .trim();
          // Server-chip click logs are diagnostic only.
          if (fullMsg.contains('[SERVER_CLICK]')) return;
          final fromBody = fullMsg.contains('[FETCH_BODY]') ||
              fullMsg.contains('[XHR_BODY]');
          _processUrl(
            streamUrl,
            frameUrl ?? fallbackReferer,
            confirmedPlaylistBody: fromBody,
          );
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


  void _processUrl(
    String rUrl,
    String referer, {
    bool confirmedPlaylistBody = false,
  }) {
    final proxyPlaylist = confirmedPlaylistBody && _isEmbedProxyPlaylistUrl(rUrl);
    if (!isPlayableStreamUrl(rUrl) && !proxyPlaylist) {
      final lower = rUrl.toLowerCase();
      if (lower.contains('/api/proxy') ||
          lower.contains('/api/sources') ||
          lower.startsWith('blob:') ||
          lower.contains('m3u8')) {
        _log('Rejected candidate (not playable URL): $rUrl');
      }
      return;
    }

    final playbackReferer = _playbackReferer(referer);

    // Check audio only in the URL path (not query params)
    final pathOnly = Uri.tryParse(rUrl)?.path ?? rUrl;
    if (pathOnly.contains('/audio/') || pathOnly.contains('audio_')) {
      _log('AUDIO DETECTED: $rUrl');
      _capturedAudio = rUrl;
      _capturedHeaders ??= _buildHeaders(playbackReferer);
    } else {
      _log('VIDEO/STREAM DETECTED: $rUrl');

      if (!_detectedVideoUrls.contains(rUrl)) {
        _detectedVideoUrls.add(rUrl);
      }

      _capturedVideo = _selectBestQuality(_detectedVideoUrls);
      _capturedHeaders ??= _buildHeaders(playbackReferer);
    }

    if (_capturedVideo == null) return;

    // SPA / multi-server embeds load streams after boot or chip switch —
    // do not complete on weak hits like PWA manifest links.
    if (_shouldDeferEarlyComplete(referer) ||
        _shouldDeferEarlyComplete(_originalEmbedUrl ?? '')) {
      if (isStrongStreamUrl(_capturedVideo!) ||
          _isEmbedProxyPlaylistUrl(_capturedVideo!)) {
        _completeWithCaptured(playbackReferer);
      }
      return;
    }

    if (_capturedAudio != null || !referer.contains('anitaro')) {
      _completeWithCaptured(playbackReferer);
    }
  }

  /// `/api/proxy` URLs whose response body was `#EXTM3U` (1embed / VidSrc.sbs).
  static bool _isEmbedProxyPlaylistUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/api/proxy') &&
        (lower.contains('sig=') || lower.contains('1embed'));
  }

  /// Prefer the canonical embed page as Referer when FRAME is the stream CDN.
  String _playbackReferer(String frameOrFallback) {
    final embed = _originalEmbedUrl;
    if (embed == null || embed.isEmpty) return frameOrFallback;
    final frameHost = Uri.tryParse(frameOrFallback)?.host.toLowerCase() ?? '';
    final streamHost =
        Uri.tryParse(_capturedVideo ?? '')?.host.toLowerCase() ?? '';
    if (streamHost.isNotEmpty && frameHost == streamHost) return embed;
    if (frameHost.contains('hydrastreaming') ||
        frameHost.contains('goodstream') ||
        frameHost.contains('cinezo')) {
      return embed;
    }
    return frameOrFallback.isNotEmpty ? frameOrFallback : embed;
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
        r.contains('vidlink.pro') ||
        r.contains('player.vidlove.cc') ||
        r.contains('vidsrc.sbs') ||
        r.contains('1embed.cc');
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
    if (_cancelled || _completing) return;
    if (_completer == null || _completer!.isCompleted) return;
    _completing = true;
    unawaited(_finishWithCookies(referer));
  }

  Future<void> _finishWithCookies(String referer) async {
    if (_cancelled) {
      _completing = false;
      return;
    }
    if (_completer == null || _completer!.isCompleted) {
      _completing = false;
      return;
    }
    final video = _capturedVideo;
    if (video == null || video.isEmpty) {
      _completing = false;
      return;
    }

    final headers = Map<String, String>.from(
      _capturedHeaders ?? _buildHeaders(referer),
    );
    final cookie = await _collectCookieHeader(
      embedUrl: _originalEmbedUrl ?? referer,
      streamUrl: video,
    );
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
      _log('Attached Cookie header (${cookie.length} chars)');
    }
    _capturedHeaders = headers;

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(ExtractedMedia(
        url: video,
        audioUrl: _capturedAudio,
        headers: headers,
        sources: _buildCapturedSources(headers),
      ));
    }
    await _cleanup();
    _completing = false;
  }

  /// Pull cookies for embed + stream hosts so CDN probe/open matches the browser.
  Future<String?> _collectCookieHeader({
    required String embedUrl,
    required String streamUrl,
  }) async {
    try {
      final manager = CookieManager.instance();
      final urls = <String>{embedUrl, streamUrl};
      final embedUri = Uri.tryParse(embedUrl);
      final streamUri = Uri.tryParse(streamUrl);
      if (embedUri != null && embedUri.hasScheme && embedUri.host.isNotEmpty) {
        urls.add(embedUri.origin);
      }
      if (streamUri != null && streamUri.hasScheme && streamUri.host.isNotEmpty) {
        urls.add(streamUri.origin);
      }
      final parts = <String>[];
      final seen = <String>{};
      for (final u in urls) {
        if (u.isEmpty) continue;
        final cookies = await manager.getCookies(url: WebUri(u));
        for (final c in cookies) {
          final key = '${c.name}=';
          if (seen.add(key)) {
            parts.add('${c.name}=${c.value}');
          }
        }
      }
      if (parts.isEmpty) return null;
      return parts.join('; ');
    } catch (e) {
      _log('Cookie harvest failed: $e');
      return null;
    }
  }

  List<StreamSource> _buildCapturedSources(Map<String, String> headers) {
    final urls = _detectedVideoUrls.isNotEmpty
        ? List<String>.from(_detectedVideoUrls)
        : (_capturedVideo != null ? [_capturedVideo!] : const <String>[]);
    return urls.map((url) {
      final lower = url.toLowerCase();
      final type = lower.contains('.m3u8') || _isEmbedProxyPlaylistUrl(url)
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

      // 2. Sniff Fetch — also pull .m3u8 out of JSON/proxy response bodies
      //    (VidSrc.sbs / 1embed serve playlists via /api/proxy without .m3u8 in the URL).
      const originalFetch = window.fetch;
      window.fetch = async function(...args) {
        const url = args[0] instanceof Request ? args[0].url : String(args[0]);
        log('FETCH', url);
        const res = await originalFetch.apply(this, args);
        if (typeof url === 'string') {
          try {
            const clone = res.clone();
            const text = await clone.text();
            const lowerUrl = url.toLowerCase();
            const looksProxy = lowerUrl.includes('/api/proxy') ||
              lowerUrl.includes('/api/sources') ||
              lowerUrl.includes('/api/v1/stream') ||
              lowerUrl.includes('proxy');
            if (looksProxy || text.includes('.m3u8') || text.trim().startsWith('#EXTM3U')) {
              if (text.trim().startsWith('#EXTM3U') && url.startsWith('http')) {
                log('FETCH_BODY', url);
              }
              const matches = text.match(/https?:\\/\\/[^"'\\s<>]+\\.m3u8[^"'\\s<>]*/gi);
              if (matches) matches.forEach((u) => log('FETCH_BODY', u));
            }
          } catch (e) {}
        }
        return res;
      };

      // 3. Sniff XHR + response bodies
      const originalXHROpen = XMLHttpRequest.prototype.open;
      const originalXHRSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function(method, url) {
        this._pt_url = url;
        log('XHR', url);
        return originalXHROpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.send = function() {
        this.addEventListener('load', function() {
          try {
            const reqUrl = String(this._pt_url || '');
            const text = this.responseText || '';
            const lowerUrl = reqUrl.toLowerCase();
            const looksProxy = lowerUrl.includes('/api/proxy') ||
              lowerUrl.includes('/api/sources') ||
              lowerUrl.includes('/api/v1/stream') ||
              lowerUrl.includes('proxy');
            if (looksProxy || text.includes('.m3u8') || text.trim().startsWith('#EXTM3U')) {
              if (text.trim().startsWith('#EXTM3U') && reqUrl.startsWith('http')) {
                log('XHR_BODY', reqUrl);
              }
              const matches = text.match(/https?:\\/\\/[^"'\\s<>]+\\.m3u8[^"'\\s<>]*/gi);
              if (matches) matches.forEach((u) => log('XHR_BODY', u));
            }
          } catch (e) {}
        });
        return originalXHRSend.apply(this, arguments);
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

      // 10. Auto-interact: play overlays + multi-server chips (VidLove Neta/Gogo/…)
      let serverChipIndex = 0;
      let lastServerClickAt = 0;
      const clickServerChips = () => {
        const nodes = Array.from(document.querySelectorAll(
          'button, [role="button"], a, div, span, li'
        ));
        const chips = [];
        const chipRe = /^(neta|gogo|mafia|fabric|server\\s*\\d+|source\\s*\\d+|hd\\s*\\d*|sd\\s*\\d*|cam|ts|hd|sd)\$/i;
        nodes.forEach((el) => {
          const text = (el.innerText || el.textContent || '').trim();
          if (!text || text.length > 28) return;
          const rect = el.getBoundingClientRect();
          if (rect.width < 24 || rect.height < 18 || rect.width > 280) return;
          const cls = (el.className || '').toString().toLowerCase();
          const looksChip = chipRe.test(text) ||
            cls.includes('server') ||
            cls.includes('source-btn') ||
            cls.includes('provider');
          if (looksChip) chips.push(el);
        });
        if (chips.length === 0) return;
        const now = Date.now();
        // Rotate chips every ~2.5s so a stuck LOADMAXING server is abandoned.
        if (now - lastServerClickAt < 2500) return;
        lastServerClickAt = now;
        const el = chips[serverChipIndex % chips.length];
        serverChipIndex++;
        const label = (el.innerText || el.textContent || '').trim();
        console.log('PT_EXTRACT: [SERVER_CLICK] ' + label + ' | FRAME: ' + window.location.href);
        try { el.click(); } catch (e) {}
        try {
          el.dispatchEvent(new MouseEvent('click', {
            view: window, bubbles: true, cancelable: true
          }));
        } catch (e) {}
      };

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

        clickServerChips();

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