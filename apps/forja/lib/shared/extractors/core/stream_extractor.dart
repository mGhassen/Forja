import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/extractors/providers/amri/amri_extractor.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
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

  /// Canonical embed URL passed to [extract] - preferred Referer for CDN opens.
  String? _originalEmbedUrl;
  EmbedExtractProfile _profile = EmbedExtractProfiles.generic;

  // Track all detected video URLs to select best quality
  final List<String> _detectedVideoUrls = [];

  /// Streams flushed before each server-chip switch (collect-all rotate).
  final List<StreamSource> _flushedChipSources = [];

  /// Count of internal server-chip switches during this sniff (dropdown / chips).
  int _serverSwitchCount = 0;
  String? _lastServerClickLabel;

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
    return {'User-Agent': _userAgent, 'Referer': referer, 'Origin': origin};
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
      _amriExtractor ??= AmriExtractor(
        onLog: (msg) => debugPrint('[Amri] $msg'),
      );

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
      final sourcesList =
          (sourcesData['sources'] as List?)
              ?.map((s) => StreamSource.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

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
  ///
  /// Manual provider switches call this while another sniff may already have
  /// a playable URL (or be mid cookie-harvest). Prefer returning that hit over
  /// discarding it as `null` - the next extract still starts cleanly after.
  Future<void> cancel() async {
    final referer = _playbackReferer(_originalEmbedUrl ?? '');
    final playable = _bestPlayableCaptured();

    // Cookie harvest already running - let it finish (do not null the completer).
    if (_completing && _completer != null && !_completer!.isCompleted) {
      _log('Cancel during complete - keeping in-flight result');
      try {
        await _completer!.future.timeout(const Duration(seconds: 8));
      } catch (_) {}
      await _cleanup();
      _activeProviderId = null;
      return;
    }

    // Stream already sniffed - complete with it instead of discarding.
    if (playable != null && _completer != null && !_completer!.isCompleted) {
      _log('Cancel with captured stream - completing instead of discard');
      _capturedVideo = playable;
      _cancelled = false;
      _completing = true;
      await _finishWithCookies(referer);
      _activeProviderId = null;
      return;
    }

    _cancelled = true;
    _completing = false;
    await _cleanup();
    _activeProviderId = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
  }

  /// Best playable URL among detected candidates (excludes audio-only clips).
  String? _bestPlayableCaptured() {
    final fromList = _detectedVideoUrls
        .where(StreamExtractor.isPlayableStreamUrl)
        .where((u) => !StreamExtractor.isAudioOnlyStreamUrl(u))
        .toList();
    if (fromList.isNotEmpty) {
      return _selectBestQuality(fromList);
    }
    final single = _capturedVideo;
    if (single != null &&
        StreamExtractor.isPlayableStreamUrl(single) &&
        !StreamExtractor.isAudioOnlyStreamUrl(single)) {
      return single;
    }
    return null;
  }

  Future<ExtractedMedia?> extract(
    String url, {
    EmbedExtractProfile? profile,
    Duration? timeout,
    String? referer,
    String? iframeWrapperBaseUrl,
    bool Function()? isCancelled,
    String? providerId,
  }) async {
    final resolved = profile ?? EmbedExtractProfiles.resolve(providerId);
    final sessionTag = resolved.id != EmbedExtractProfiles.generic.id
        ? resolved.id
        : (providerId != null && providerId.trim().isNotEmpty
              ? providerId
              : null);
    // Dispose any prior WebView without dropping the new session tag.
    await _cleanup();
    _profile = resolved;
    _activeProviderId = sessionTag;
    if (isAndroidTvHeadlessWebViewBlocked) {
      _log('Headless WebView blocked on Android TV (use WebStreamr/VSEmbed)');
      _activeProviderId = null;
      return null;
    }
    _cancelled = false;

    bool cancelled() => _cancelled || (isCancelled?.call() ?? false);

    final effectiveTimeout = timeout ?? resolved.timeout;
    final forceDirect = resolved.forceDirect;

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
    _flushedChipSources.clear();
    _serverSwitchCount = 0;
    _lastServerClickLabel = null;

    _timeoutTimer = Timer(effectiveTimeout, () {
      if (_completer != null && !_completer!.isCompleted) {
        final best = _bestPlayableCaptured();
        if (best != null) {
          // Timeout (or cancel flagged mid-sniff): still return what we have.
          _capturedVideo = best;
          _completeWithCaptured(url);
          return;
        }
        if (cancelled()) {
          _cleanup();
          _completer?.complete(null);
          return;
        }
        _log('Sniffing session timeout for: $url');
        _cleanup();
        _completer?.complete(null);
      }
    });

    _log(
      'RAW SNIFFER START: $url'
      '${referer != null ? ' (referer=$referer)' : ''}'
      '${wrapperBase != null ? ' (wrapper=$wrapperBase)' : ''}',
    );

    // Build the headless webview. There are two modes:
    //  1) Direct: load `url` itself (with optional Referer/Origin headers).
    //  2) Wrapped: load a tiny HTML page via `loadData` whose baseUrl is
    //     `wrapperBase`. We then iframe `url` inside it. The iframe
    //     receives `document.referrer = wrapperBase`, defeating
    //     embed providers that block direct loads (megaplay).
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
            source: _getRawSpyJs(_profile),
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
          useShouldOverrideUrlLoading: true,
          javaScriptCanOpenWindowsAutomatically: false,
          supportMultipleWindows: false,
          iframeAllow: 'autoplay; fullscreen; encrypted-media',
          iframeAllowFullscreen: true,
        ),
        onLoadResource: _onLoadResource(url),
        onLoadStop: _onLoadStop(),
        onConsoleMessage: _onConsoleMessage(url),
        shouldOverrideUrlLoading: _shouldOverrideUrlLoading(
          embedUrl: url,
          wrapperBase: wrapperBase,
        ),
        onCreateWindow: _onCreateWindow(),
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
            source: _getRawSpyJs(_profile),
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
          useShouldOverrideUrlLoading: true,
          javaScriptCanOpenWindowsAutomatically: false,
          supportMultipleWindows: false,
          iframeAllow: 'autoplay; fullscreen; encrypted-media',
          iframeAllowFullscreen: true,
        ),
        onLoadResource: _onLoadResource(url),
        onLoadStop: _onLoadStop(),
        onConsoleMessage: _onConsoleMessage(url),
        shouldOverrideUrlLoading: _shouldOverrideUrlLoading(embedUrl: url),
        onCreateWindow: _onCreateWindow(),
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

  void Function(InAppWebViewController, LoadedResource) _onLoadResource(
    String fallbackReferer,
  ) => (controller, resource) {
    final rUrl = resource.url.toString();
    _log('Resource: $rUrl');
    _processUrl(rUrl, fallbackReferer);
  };

  void Function(InAppWebViewController, WebUri?) _onLoadStop() =>
      (controller, loadedUrl) async {
        _log('Page loaded: $loadedUrl');
        await controller.evaluateJavascript(source: _getRawSpyJs(_profile));
      };

  void Function(InAppWebViewController, ConsoleMessage) _onConsoleMessage(
    String fallbackReferer,
  ) => (controller, consoleMessage) {
    final msg = consoleMessage.message;
    _log('Console: $msg');
    if (msg.contains('PT_EXTRACT:')) {
      String fullMsg = msg
          .substring(msg.indexOf('PT_EXTRACT:') + 'PT_EXTRACT:'.length)
          .trim();
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
          .replaceFirst('[HLS_SRC]', '')
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
      // Server switch: stash the previous chip's playable URLs, then clear so
      // a dead default cannot win — rotate profiles still keep every hit.
      if (fullMsg.contains('[SERVER_CLICK]')) {
        final label = streamUrl;
        if (label.isNotEmpty &&
            label.toLowerCase() ==
                (_lastServerClickLabel ?? '').toLowerCase()) {
          _log('Ignoring duplicate SERVER_CLICK: $label');
          return;
        }
        _flushCurrentChipSources();
        _lastServerClickLabel = label;
        _serverSwitchCount++;
        _detectedVideoUrls.clear();
        _capturedVideo = null;
        _capturedAudio = null;
        _log('Server chip switched (#$_serverSwitchCount): $label');
        return;
      }
      final fromBody =
          fullMsg.contains('[FETCH_BODY]') ||
          fullMsg.contains('[XHR_BODY]') ||
          fullMsg.contains('[HLS_SRC]');
      _processUrl(
        streamUrl,
        frameUrl ?? fallbackReferer,
        confirmedPlaylistBody: fromBody,
      );
    }
  };

  Future<NavigationActionPolicy?> Function(
    InAppWebViewController,
    NavigationAction,
  )
  _shouldOverrideUrlLoading({required String embedUrl, String? wrapperBase}) =>
      (controller, navigationAction) async {
        final target = navigationAction.request.url?.toString() ?? '';
        if (target.isEmpty) return NavigationActionPolicy.ALLOW;

        if (_isBlockedAdOrTrackerUrl(target)) {
          _log('Blocked ad/tracker navigation: $target');
          return NavigationActionPolicy.CANCEL;
        }

        if (!navigationAction.isForMainFrame) {
          return NavigationActionPolicy.ALLOW;
        }

        if (_isAllowedMainFrameNavigation(
          target,
          embedUrl: embedUrl,
          wrapperBase: wrapperBase,
        )) {
          return NavigationActionPolicy.ALLOW;
        }

        if (isPlayableStreamUrl(target)) {
          _processUrl(target, embedUrl);
          return NavigationActionPolicy.ALLOW;
        }

        _log('Blocked main-frame redirect: $target');
        return NavigationActionPolicy.CANCEL;
      };

  Future<bool?> Function(InAppWebViewController, CreateWindowAction)
  _onCreateWindow() => (controller, createWindowAction) async {
    final url = createWindowAction.request.url?.toString();
    _log('Blocked popup window${url == null ? '' : ': $url'}');
    return true;
  };

  String _buildIframeWrapperHtml(String embedUrl) {
    // Minimal page: full-bleed iframe with autoplay + fullscreen perms.
    // Because we load this via `loadData(baseUrl: …)`, the iframe's
    // `document.referrer` and `window.parent.location.origin` reflect the
    // base URL (e.g. https://www.enma.lol/), which is what megaplay
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

  bool _isAllowedMainFrameNavigation(
    String target, {
    required String embedUrl,
    String? wrapperBase,
  }) {
    final targetUri = Uri.tryParse(target);
    if (targetUri == null) return false;
    if (targetUri.scheme == 'about' || targetUri.scheme == 'data') return true;
    if (!targetUri.isScheme('http') && !targetUri.isScheme('https')) {
      return false;
    }
    // AutoEmbed (and similar) anti-iframe pages - never treat as success.
    final path = targetUri.path.toLowerCase();
    if (path == '/asb.html' || path.endsWith('/asb.html')) {
      return false;
    }
    final embedUri = Uri.tryParse(embedUrl);
    final wrapperUri = wrapperBase == null ? null : Uri.tryParse(wrapperBase);
    if (_sameSite(targetUri, embedUri) || _sameSite(targetUri, wrapperUri)) {
      return true;
    }

    // Some embeds legitimately bounce between player subdomains before loading.
    final host = targetUri.host.toLowerCase();
    final embedHost = embedUri?.host.toLowerCase() ?? '';
    if (embedHost.isNotEmpty &&
        (host.endsWith('.$embedHost') || embedHost.endsWith('.$host'))) {
      return true;
    }
    // 2embed.online docs → 2embed.stream player (different registrable domains).
    if (_is2embedFamily(host) && _is2embedFamily(embedHost)) {
      return true;
    }
    return false;
  }

  static bool _is2embedFamily(String host) {
    return host == '2embed.stream' ||
        host == 'www.2embed.online' ||
        host == '2embed.online' ||
        host == 'www.2embed.stream';
  }

  static bool _sameSite(Uri a, Uri? b) {
    if (b == null || b.host.isEmpty) return false;
    if (a.host.toLowerCase() == b.host.toLowerCase()) return true;
    return _registrableDomain(a.host) == _registrableDomain(b.host);
  }

  static String _registrableDomain(String host) {
    final parts = host
        .toLowerCase()
        .split('.')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 2) return parts.join('.');
    return parts.sublist(parts.length - 2).join('.');
  }

  bool _isBlockedAdOrTrackerUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    final lower = url.toLowerCase();
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (isPlayableStreamUrl(url)) return false;
    const blockedHostParts = [
      'doubleclick.net',
      'googlesyndication.com',
      'google-analytics.com',
      'googletagmanager.com',
      'adservice.google.',
      'popads.net',
      'popcash.net',
      'onclickads.net',
      'propellerads.com',
      'exoclick.com',
      'adsterra.',
      'effectivecpm',
      'hilltopads',
      'trafficjunky',
      'taboola.com',
      'outbrain.com',
    ];
    if (blockedHostParts.any(host.contains)) return true;
    return lower.contains('/ads/') ||
        lower.contains('/adserver') ||
        lower.contains('vast.php') ||
        lower.contains('vast.xml') ||
        lower.contains('popunder') ||
        lower.contains('prebid');
  }

  void _processUrl(
    String rUrl,
    String referer, {
    bool confirmedPlaylistBody = false,
  }) {
    final proxyPlaylist =
        confirmedPlaylistBody &&
        _profile.acceptProxyPlaylistBodies &&
        _isEmbedProxyPlaylistUrl(rUrl);
    // Opaque same-origin playlist proxies: body already proved `#EXTM3U`
    // (or HLS.js loadSource) even when the URL has no `.m3u8` suffix.
    final confirmedHttpPlaylist =
        confirmedPlaylistBody && _isHttpOrHttpsUrl(rUrl);
    if (!isPlayableStreamUrl(rUrl) && !proxyPlaylist && !confirmedHttpPlaylist) {
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

    // Audio-only CDN paths (e.g. VidLove/111movies `tran-audio`) - never
    // treat as the primary video when deferring for a strong stream.
    if (isAudioOnlyStreamUrl(rUrl)) {
      _log('AUDIO DETECTED: $rUrl');
      _capturedAudio = rUrl;
      _capturedHeaders ??= _buildHeaders(playbackReferer);
      return;
    }

    _log('VIDEO/STREAM DETECTED: $rUrl');

    if (!_detectedVideoUrls.contains(rUrl)) {
      _detectedVideoUrls.add(rUrl);
    }

    _capturedVideo = _selectBestQuality(_detectedVideoUrls);
    _capturedHeaders ??= _buildHeaders(playbackReferer);

    if (_capturedVideo == null) return;

    // SPA / multi-server embeds: wait for HLS/DASH (not progressive mp4).
    if (_profile.deferUntilStrongStream) {
      final strong =
          isDeferredStrongStreamUrl(_capturedVideo!) ||
          confirmedHttpPlaylist ||
          (_profile.acceptProxyPlaylistBodies &&
              _isEmbedProxyPlaylistUrl(_capturedVideo!));
      if (!strong) return;
      // Chip-rotate hosts: keep sniffing every server chip until timeout so
      // all detected playlists land in `sources` - no first-hit early complete.
      if (_profile.rotateServerChips) return;
      // Legacy hold: wait for at least one chip switch before completing.
      if (_profile.rotateBeforeComplete && _serverSwitchCount == 0) {
        _log(
          'Holding strong stream until server rotation '
          '(rotateBeforeComplete): $_capturedVideo',
        );
        return;
      }
      _completeWithCaptured(playbackReferer);
      return;
    }

    if (_profile.completeOnlyWithAudio && _capturedAudio == null) {
      return;
    }
    _completeWithCaptured(playbackReferer);
  }

  /// `/api/proxy` URLs whose response body was `#EXTM3U`.
  static bool _isEmbedProxyPlaylistUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/api/proxy') &&
        (lower.contains('sig=') || lower.contains('1embed'));
  }

  static bool _isHttpOrHttpsUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    return uri.isScheme('http') || uri.isScheme('https');
  }

  /// Prefer the canonical embed page as Referer when FRAME is the stream CDN.
  String _playbackReferer(String frameOrFallback) {
    final embed = _originalEmbedUrl;
    if (embed == null || embed.isEmpty) return frameOrFallback;
    final frameHost = Uri.tryParse(frameOrFallback)?.host.toLowerCase() ?? '';
    final streamHost =
        Uri.tryParse(_capturedVideo ?? '')?.host.toLowerCase() ?? '';
    if (streamHost.isNotEmpty && frameHost == streamHost) return embed;
    for (final host in _profile.cdnHostsPreferEmbedReferer) {
      if (host.isNotEmpty && frameHost.contains(host.toLowerCase())) {
        return embed;
      }
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
    // Cinesrc / ice.* proxies: `?m3u8=<token>` (no `.m3u8` in the path).
    if (lower.contains('m3u8=')) return true;
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
    // VidLove / 111movies: player sets video.src to signed `/api?d=&internal_token=`
    // (no .m3u8/.mp4 suffix). Browser plays that URL; treat as media.
    if (isOpaqueSignedMediaProxyUrl(trimmed)) return true;
    return false;
  }

  /// VidLove-style opaque media proxy (`/api?d=…&internal_token=…`).
  static bool isOpaqueSignedMediaProxyUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
    final path = uri.path;
    if (path != '/api' && path != '/api/') return false;
    final d = uri.queryParameters['d']?.trim() ?? '';
    final token = uri.queryParameters['internal_token']?.trim() ?? '';
    return d.isNotEmpty && token.isNotEmpty;
  }

  /// Audio-only / secondary tracks that look like `.mp4` but are not the film.
  static bool isAudioOnlyStreamUrl(String url) {
    final path =
        Uri.tryParse(url.trim())?.path.toLowerCase() ??
        url.trim().toLowerCase();
    return path.contains('/tran-audio/') ||
        path.contains('/audio/') ||
        path.contains('audio_') ||
        path.contains('/tran-audio') ||
        path.contains('tran-audio/');
  }

  static bool isStrongStreamUrl(String url) {
    if (isAudioOnlyStreamUrl(url)) return false;
    final lower = url.toLowerCase();
    // Progressive mp4 can be a stale signed clip; prefer playlist formats when
    // [EmbedExtractProfile.deferUntilStrongStream] is waiting for a real open.
    if (lower.contains('.m3u8')) return true;
    if (lower.contains('m3u8=')) return true;
    if (lower.contains('.mpd')) return true;
    if (lower.contains('playlist') && !lower.contains('webmanifest')) {
      return true;
    }
    // Non-deferred callers still treat clean mp4 as strong via playable +
    // immediate complete; deferred profiles wait for HLS/DASH above.
    if (lower.contains('.mp4') && !lower.contains('googlevideo.com')) {
      return true;
    }
    return false;
  }

  /// Strong enough to end a [EmbedExtractProfile.deferUntilStrongStream] sniff.
  /// Excludes progressive mp4 so multi-server embeds can rotate past audio clips.
  static bool isDeferredStrongStreamUrl(String url) {
    if (isAudioOnlyStreamUrl(url)) return false;
    if (isOpaqueSignedMediaProxyUrl(url)) return true;
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('m3u8=') ||
        lower.contains('.mpd') ||
        (lower.contains('playlist') && !lower.contains('webmanifest'));
  }

  String _selectBestQuality(List<String> urls) {
    final playable = urls
        .where(StreamExtractor.isPlayableStreamUrl)
        .where((u) => !StreamExtractor.isAudioOnlyStreamUrl(u))
        .toList();
    if (playable.isEmpty) {
      final any = urls.where(StreamExtractor.isPlayableStreamUrl).toList();
      return any.isNotEmpty ? any.first : (urls.isNotEmpty ? urls.first : '');
    }

    // Quality priority: 4K > 2160p > 1440p > 1080p > 720p > 480p > 360p
    final qualityOrder = [
      '4K',
      '2160p',
      '1440p',
      '1080p',
      '720p',
      '480p',
      '360p',
    ];

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
    final dash = playable.where((u) => u.toLowerCase().contains('.mpd'));
    if (dash.isNotEmpty) return dash.first;

    return playable.first;
  }

  void _completeWithCaptured(String referer) {
    if (_completing) return;
    if (_completer == null || _completer!.isCompleted) return;
    _completing = true;
    unawaited(_finishWithCookies(referer));
  }

  Future<void> _finishWithCookies(String referer) async {
    if (_completer == null || _completer!.isCompleted) {
      _completing = false;
      return;
    }
    // Prefer a non-audio playable URL if we have one (cancel / late refine).
    final video = _bestPlayableCaptured() ?? _capturedVideo;
    if (video == null || video.isEmpty) {
      _completing = false;
      return;
    }
    _capturedVideo = video;
    // Once we have a playable URL, finish even if cancel was requested -
    // switching providers must not throw away an already-found stream.

    final headers = Map<String, String>.from(
      _capturedHeaders ?? _buildHeaders(referer),
    );
    if (_profile.harvestCookies) {
      final cookie = await _collectCookieHeader(
        embedUrl: _originalEmbedUrl ?? referer,
        streamUrl: video,
      );
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
        _log('Attached Cookie header (${cookie.length} chars)');
      }
    }
    _capturedHeaders = headers;

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(
        ExtractedMedia(
          url: video,
          audioUrl: _capturedAudio,
          headers: headers,
          sources: _buildCapturedSources(headers),
        ),
      );
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
      if (streamUri != null &&
          streamUri.hasScheme &&
          streamUri.host.isNotEmpty) {
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

  void _flushCurrentChipSources() {
    final urls = _detectedVideoUrls.isNotEmpty
        ? List<String>.from(_detectedVideoUrls)
        : (_capturedVideo != null ? [_capturedVideo!] : const <String>[]);
    if (urls.isEmpty) return;
    final headers = Map<String, String>.from(
      _capturedHeaders ??
          _buildHeaders(_originalEmbedUrl ?? _playerOriginFallback()),
    );
    final label = _chipTitleLabel();
    for (final url in urls) {
      if (!isPlayableStreamUrl(url) || isAudioOnlyStreamUrl(url)) continue;
      if (_flushedChipSources.any((s) => s.url == url)) continue;
      _flushedChipSources.add(
        _streamSourceForUrl(url, headers: headers, serverLabel: label),
      );
    }
  }

  String? _chipTitleLabel() {
    final clicked = _lastServerClickLabel?.trim();
    if (clicked != null && clicked.isNotEmpty) return clicked;
    if (_profile.serverChipLabels.isNotEmpty) {
      return _profile.serverChipLabels.first;
    }
    return null;
  }

  String _playerOriginFallback() {
    final embed = _originalEmbedUrl;
    if (embed == null || embed.isEmpty) return 'https://player.videasy.to/';
    return embed;
  }

  StreamSource _streamSourceForUrl(
    String url, {
    required Map<String, String> headers,
    String? serverLabel,
  }) {
    final lower = url.toLowerCase();
    final type =
        lower.contains('.m3u8') ||
            (_profile.acceptProxyPlaylistBodies &&
                _isEmbedProxyPlaylistUrl(url))
        ? 'hls'
        : lower.contains('.mpd')
        ? 'dash'
        : 'mp4';
    final quality = lower.contains('h265') || lower.contains('hevc')
        ? 'HEVC'
        : lower.contains('1080')
        ? '1080p'
        : lower.contains('720')
        ? '720p'
        : 'Stream';
    final label = serverLabel?.trim();
    final title = (label != null && label.isNotEmpty)
        ? '$label · $quality'
        : quality;
    return StreamSource(
      url: url,
      title: title,
      type: type,
      headers: headers,
      providerId: _activeProviderId ??
          (_profile.id != EmbedExtractProfiles.generic.id
              ? _profile.id
              : null),
      catalogUrl: url,
    );
  }

  List<StreamSource> _buildCapturedSources(Map<String, String> headers) {
    _flushCurrentChipSources();
    if (_flushedChipSources.isNotEmpty) {
      return List<StreamSource>.from(_flushedChipSources);
    }
    final urls = _detectedVideoUrls.isNotEmpty
        ? List<String>.from(_detectedVideoUrls)
        : (_capturedVideo != null ? [_capturedVideo!] : const <String>[]);
    return [
      for (final url in urls)
        _streamSourceForUrl(
          url,
          headers: headers,
          serverLabel: _chipTitleLabel(),
        ),
    ];
  }

  String _getRawSpyJs(EmbedExtractProfile profile) {
    final rotate = profile.rotateServerChips;
    final labelsJson = profile.serverChipLabels
        .map((s) => '"${s.toLowerCase().replaceAll('"', '')}"')
        .join(',');
    final acceptProxyBody = profile.acceptProxyPlaylistBodies;
    final providerIdJs = profile.id.replaceAll("'", r"\'");
    return """
    (function() {
      if (window.pt_raw_injected) return;
      window.pt_raw_injected = true;
      const ROTATE_SERVER_CHIPS = $rotate;
      const SERVER_CHIP_LABELS = [$labelsJson];
      const ACCEPT_PROXY_BODY = $acceptProxyBody;
      const PROVIDER_ID = '$providerIdJs';
      const IS_VIDROCK = PROVIDER_ID === 'vidrock';
      const IS_VIDSRC = PROVIDER_ID === 'vidsrc';

      const log = (type, url) => {
        if (!url || typeof url !== 'string' || url.startsWith('data:')) return;
        console.log('PT_EXTRACT: [' + type + '] ' + url + ' | FRAME: ' + window.location.href);
      };

      console.log('PT_LOG: Sniffer Active on ' + window.location.href
        + ' rotateChips=' + ROTATE_SERVER_CHIPS
        + ' proxyBody=' + ACCEPT_PROXY_BODY);

      window.open = function() { return null; };
      window.alert = function() { return true; };

      const originalFetch = window.fetch;
      window.fetch = async function(...args) {
        const raw = args[0] instanceof Request ? args[0].url : String(args[0]);
        let absUrl = raw;
        try { absUrl = new URL(raw, window.location.href).href; } catch (e) {}
        log('FETCH', absUrl);
        const res = await originalFetch.apply(this, args);
        try {
          const clone = res.clone();
          const text = await clone.text();
          const lowerUrl = absUrl.toLowerCase();
          const looksProxy = lowerUrl.includes('/api/proxy') ||
            lowerUrl.includes('/api/sources') ||
            lowerUrl.includes('/api/v1/stream') ||
            lowerUrl.includes('internal_token=') ||
            (lowerUrl.includes('/api?') && lowerUrl.includes('d=')) ||
            lowerUrl.includes('proxy');
          if (text.includes('.m3u8') || text.trim().startsWith('#EXTM3U') ||
              (ACCEPT_PROXY_BODY && looksProxy)) {
            if (text.trim().startsWith('#EXTM3U') && absUrl.startsWith('http')) {
              log('FETCH_BODY', absUrl);
            }
            const matches = text.match(/https?:\\/\\/[^"'\\s<>]+\\.m3u8[^"'\\s<>]*/gi);
            if (matches) matches.forEach((u) => log('FETCH_BODY', u));
          }
        } catch (e) {}
        return res;
      };

      const originalXHROpen = XMLHttpRequest.prototype.open;
      const originalXHRSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function(method, url) {
        let abs = String(url || '');
        try { abs = new URL(abs, window.location.href).href; } catch (e) {}
        this._pt_url = abs;
        log('XHR', abs);
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
              lowerUrl.includes('internal_token=') ||
              (lowerUrl.includes('/api?') && lowerUrl.includes('d=')) ||
              lowerUrl.includes('proxy');
            if (text.includes('.m3u8') || text.trim().startsWith('#EXTM3U') ||
                (ACCEPT_PROXY_BODY && looksProxy)) {
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

      // VidFast / MSE players: real playlist is Hls.loadSource(url), video.src is blob:.
      const hookHlsProto = (H) => {
        if (!H || !H.prototype || H.prototype.__pt_hls_hooked) return;
        H.prototype.__pt_hls_hooked = true;
        const origLoad = H.prototype.loadSource;
        if (typeof origLoad !== 'function') return;
        H.prototype.loadSource = function(url) {
          try {
            let abs = String(url || '');
            try { abs = new URL(abs, window.location.href).href; } catch (e) {}
            if (abs) log('HLS_SRC', abs);
          } catch (e) {}
          return origLoad.apply(this, arguments);
        };
      };
      const hookHls = () => {
        hookHlsProto(window.Hls);
        hookHlsProto(window.hls);
        hookHlsProto(window.Hlsjs);
      };
      hookHls();
      setInterval(hookHls, 400);
      try {
        let _hls = window.Hls;
        Object.defineProperty(window, 'Hls', {
          configurable: true,
          get() { return _hls; },
          set(v) { _hls = v; hookHlsProto(v); }
        });
      } catch (e) {}


      const OriginalWorker = window.Worker;
      window.Worker = function(scriptURL, options) {
        log('WORKER', scriptURL);
        return new OriginalWorker(scriptURL, options);
      };

      const originalPostMessage = window.postMessage;
      window.postMessage = function(message, targetOrigin, transfer) {
        if (typeof message === 'string') log('POSTMESSAGE', message);
        return originalPostMessage.apply(this, arguments);
      };

      const originalCreateObjectURL = URL.createObjectURL;
      URL.createObjectURL = function(obj) {
        const url = originalCreateObjectURL.apply(this, arguments);
        log('BLOB_URL', url);
        return url;
      };

      const originalSetAttribute = Element.prototype.setAttribute;
      Element.prototype.setAttribute = function(name, value) {
        if (name === 'src' || name === 'data-src') {
           log('ATTR_' + name.toUpperCase(), value);
        }
        return originalSetAttribute.apply(this, arguments);
      };

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

      // Sniff must never leak audio over the real player (manual Check / Auto).
      const muteMedia = (el) => {
        if (!el) return;
        try { el.muted = true; el.volume = 0; el.setAttribute('muted', ''); } catch (e) {}
      };
      const muteAllMedia = () => {
        try {
          document.querySelectorAll('video,audio').forEach(muteMedia);
        } catch (e) {}
      };
      if (!window.__ptMuteGuard) {
        window.__ptMuteGuard = true;
        document.addEventListener('play', function (e) {
          const t = e.target;
          if (!t || (t.tagName !== 'VIDEO' && t.tagName !== 'AUDIO')) return;
          muteMedia(t);
        }, true);
        new MutationObserver((mutations) => {
          mutations.forEach((m) => {
            m.addedNodes.forEach((node) => {
              if (!node || node.nodeType !== 1) return;
              if (node.tagName === 'VIDEO' || node.tagName === 'AUDIO') muteMedia(node);
              if (node.querySelectorAll) node.querySelectorAll('video,audio').forEach(muteMedia);
            });
          });
        }).observe(document.documentElement, { childList: true, subtree: true });
      }

      const originalPlay = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function() {
        muteMedia(this);
        if (this.src) log('MEDIA_PLAY', this.src);
        return originalPlay.apply(this, arguments);
      };

      let serverChipIndex = 0;
      let lastServerClickAt = 0;
      const triedServerLabels = new Set();
      const chipText = (el) => (el.innerText || el.textContent || '').trim()
        .replace(/\\s+/g, ' ');
      const isActiveChip = (el) => {
        const cls = (el.className || '').toString().toLowerCase();
        return cls.includes('active') ||
          cls.includes('border-player-accent') ||
          cls.includes('bg-player-accent') ||
          el.getAttribute('aria-pressed') === 'true' ||
          el.getAttribute('aria-selected') === 'true';
      };
      const isDropdownToggle = (el) => {
        const cls = (el.className || '').toString().toLowerCase();
        const id = (el.id || '').toLowerCase();
        return id === 'srvbtn' ||
          cls.includes('srv-dropdown-btn') ||
          cls.includes('srv-btn-label') ||
          cls.includes('srv-chevron') ||
          cls.includes('srv-dot');
      };
      const openServerDropdown = () => {
        const menu = document.getElementById('srvMenu') ||
          document.querySelector('.srv-menu');
        const btn = document.getElementById('srvBtn') ||
          document.querySelector('.srv-dropdown-btn');
        if (btn && menu && !menu.classList.contains('open')) {
          try { btn.click(); } catch (e) {}
          try {
            btn.dispatchEvent(new MouseEvent('click', {
              view: window, bubbles: true, cancelable: true
            }));
          } catch (e) {}
        }
        // VidRock-only: panel mounts only while open (title="Server List").
        // Do NOT click generic "server" controls on VidSrc.sbs / other hosts.
        if (IS_VIDROCK && !document.querySelector('[data-server-list]')) {
          const toggles = Array.from(document.querySelectorAll(
            'button[title], [role="button"][title]'
          ));
          for (const el of toggles) {
            const t = (
              (el.getAttribute('title') || '') + ' ' +
              (el.getAttribute('aria-label') || '')
            ).toLowerCase();
            if (t.includes('server list')) {
              try { el.click(); } catch (e) {}
              try {
                el.dispatchEvent(new MouseEvent('click', {
                  view: window, bubbles: true, cancelable: true
                }));
              } catch (e) {}
              console.log('PT_EXTRACT: [SERVER_PANEL] open | FRAME: ' +
                window.location.href);
              break;
            }
          }
        }
      };
      const clickEl = (el) => {
        let label = chipText(el);
        if (IS_VIDROCK) {
          // Rows: name in `.font-normal.text-sm`, language on next line.
          const nameNode = el.querySelector(
            '.font-normal.text-sm, .font-normal, [class*="font-normal"]'
          );
          if (nameNode) {
            const n = (nameNode.textContent || '').trim().replace(/\\s+/g, ' ');
            if (n) label = n;
          }
          triedServerLabels.add(chipText(el).toLowerCase());
        }
        const lower = label.toLowerCase();
        triedServerLabels.add(lower);
        console.log('PT_EXTRACT: [SERVER_CLICK] ' + label + ' | FRAME: ' + window.location.href);
        try { el.click(); } catch (e) {}
        try {
          el.dispatchEvent(new MouseEvent('click', {
            view: window, bubbles: true, cancelable: true
          }));
        } catch (e) {}
      };
      const clickServerChips = () => {
        if (!ROTATE_SERVER_CHIPS) return;
        const now = Date.now();
        // Named multi-server dropdowns need longer dwell so a working mirror
        // (e.g. PRO Multi) can emit HLS before we abandon it for the next chip.
        const rotateGapMs = SERVER_CHIP_LABELS.length > 0 ? 5500 : 2500;
        if (now - lastServerClickAt < rotateGapMs) return;

        openServerDropdown();

        // VidSrc.sbs-style: only real menu rows. The closed dropdown button
        // also shows the active label ("PRO Multi") and must not be re-clicked.
        const menuItems = Array.from(document.querySelectorAll(
          'button.srv-menu-item, .srv-menu-item[data-idx], .srv-menu-item'
        )).filter((el) => {
          const text = chipText(el);
          return text && text.length <= 28 && !isDropdownToggle(el);
        });

        let chips = menuItems;
        // VidRock-only: rows are `div.cursor-pointer` (not <button>).
        if (IS_VIDROCK && chips.length === 0) {
          chips = Array.from(document.querySelectorAll(
            '[data-server-list] .cursor-pointer, ' +
            '[data-server-list] [class*="rounded-lg"][class*="border"]'
          )).filter((el) => {
            if (el.tagName === 'BUTTON' || el.closest('button')) return false;
            const text = chipText(el);
            if (!text || text.length > 60) return false;
            if (/^(original audio|default)\$/i.test(text)) return false;
            const rect = el.getBoundingClientRect();
            return rect.width >= 40 && rect.height >= 28 && rect.width <= 480;
          });
        }
        if (chips.length === 0) {
          const nodes = Array.from(document.querySelectorAll(
            'button, [role="button"], a, div, span, li'
          ));
          const labelSet = new Set(SERVER_CHIP_LABELS.map((s) => String(s).toLowerCase()));
          nodes.forEach((el) => {
            if (isDropdownToggle(el)) return;
            const text = chipText(el);
            if (!text || text.length > 28) return;
            const rect = el.getBoundingClientRect();
            if (rect.width < 24 || rect.height < 18 || rect.width > 280) return;
            const lower = text.toLowerCase();
            const cls = (el.className || '').toString().toLowerCase();
            const labeled = labelSet.size > 0 &&
                Array.from(labelSet).some((label) => lower === label || lower.startsWith(label));
            const generic = /^(server\\s*\\d+|source\\s*\\d+|hd\\s*\\d*|sd\\s*\\d*|cam|ts|hd|sd)\$/i.test(text);
            const classHit = cls.includes('server') || cls.includes('source-btn');
            if (labeled || (labelSet.size === 0 && (generic || classHit))) chips.push(el);
          });
        }
        if (chips.length === 0) return;

        // Treat the active row as already visited so we never re-click it
        // (and so the closed dropdown button cannot steal the next prefer).
        chips.forEach((c) => {
          if (isActiveChip(c)) triedServerLabels.add(chipText(c).toLowerCase());
        });

        // Prefer configured label order: skip active + already-tried.
        let el = null;
        if (SERVER_CHIP_LABELS.length > 0) {
          for (let i = 0; i < SERVER_CHIP_LABELS.length; i++) {
            const want = String(SERVER_CHIP_LABELS[i]).toLowerCase();
            const match = chips.find((c) => {
              const lower = chipText(c).toLowerCase();
              return (lower === want || lower.startsWith(want)) &&
                !isActiveChip(c) &&
                !triedServerLabels.has(lower);
            });
            if (match) { el = match; break; }
          }
        }
        if (!el) {
          const untried = chips.filter((c) =>
            !isActiveChip(c) && !triedServerLabels.has(chipText(c).toLowerCase())
          );
          if (untried.length > 0) {
            el = untried[serverChipIndex % untried.length];
            serverChipIndex++;
          }
        }
        // All servers tried once - allow a second pass (do not spam the active one).
        if (!el) {
          if (triedServerLabels.size >= chips.length) {
            triedServerLabels.clear();
          }
          return;
        }

        lastServerClickAt = now;
        clickEl(el);
      };

      // VSEmbed landing (`autoStart:false`): streams only load after Play
      // injects `#player_frame` → `/embed/player/…?vs=…` (stream_urls + vsdec).
      // Generic play-button clicks often miss `#bigPlay` (SVG-only, or a bad
      // CSS `[class*="play" i]` selector aborting interact). Force the boot.
      const bootVsembedLanding = () => {
        if (!IS_VIDSRC) return;
        const cfg = window.CFG || {};
        if (!cfg.playerUrl || document.getElementById('player_frame')) return;
        const big = document.getElementById('bigPlay') ||
          document.querySelector('button.jw-bigplay, .jw-bigplay');
        if (big) {
          try { big.click(); } catch (e) {}
          try {
            big.dispatchEvent(new MouseEvent('click', {
              view: window, bubbles: true, cancelable: true
            }));
          } catch (e) {}
        }
        if (document.getElementById('player_frame')) return;
        const wrap = document.getElementById('player');
        if (!wrap) return;
        if (big) {
          try { big.style.display = 'none'; } catch (e) {}
        }
        const frame = document.createElement('iframe');
        frame.id = 'player_frame';
        frame.src = cfg.playerUrl;
        frame.setAttribute(
          'allow',
          'autoplay; fullscreen; picture-in-picture; encrypted-media'
        );
        frame.setAttribute('allowfullscreen', '');
        frame.setAttribute('scrolling', 'no');
        frame.setAttribute('referrerpolicy', 'origin');
        frame.style.cssText =
          'position:absolute;inset:0;width:100%;height:100%;border:0;' +
          'display:block;z-index:20;background:#000';
        wrap.appendChild(frame);
        let abs = cfg.playerUrl;
        try { abs = new URL(cfg.playerUrl, window.location.href).href; } catch (e) {}
        log('VS_BOOT', abs);
      };

      const interact = () => {
        bootVsembedLanding();
        const centerX = window.innerWidth / 2;
        const centerY = window.innerHeight / 2;
        for (let i = 0; i < 3; i++) {
          const el = document.elementFromPoint(centerX, centerY);
          if (el) {
            el.click();
            el.dispatchEvent(new MouseEvent('click', {
              view: window, bubbles: true, cancelable: true,
              clientX: centerX, clientY: centerY
            }));
          }
        }
        const selectors = [
          '#bigPlay', 'button.jw-bigplay', '.jw-bigplay',
          '.play-icon-main', '.jw-icon-display', '.jw-display-icon-container', '.jw-icon-playback',
          '.jw-button-color', '#play-button', '.play-button', '.v-play-button',
          '.vjs-big-play-button', '[class*="play"]', '[id*="play"]',
          '.play-icon', '.play_icon', '.play-btn', '.play_btn',
          '.click_to_play', '.overlay', '#player_overlay'
        ];
        selectors.forEach((selector) => {
          let nodes;
          try { nodes = document.querySelectorAll(selector); } catch (e) { return; }
          nodes.forEach((btn) => {
            const text = (btn.innerText || btn.textContent || '').toLowerCase();
            const id = (btn.id || '').toLowerCase();
            const cls = (btn.className || '').toString().toLowerCase();
            const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
            if (text.includes('play') || id.includes('play') ||
                cls.includes('play') || cls.includes('overlay') ||
                aria.includes('play')) {
              try { btn.click(); } catch (e) {}
            }
          });
        });
        clickServerChips();
        muteAllMedia();
        document.querySelectorAll('video').forEach((v) => {
          muteMedia(v);
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
      final webView = _headlessWebView;
      // Null first so a hung dispose cannot block the next extract() forever
      // (WKWebView dispose has been observed to never return on macOS).
      _headlessWebView = null;
      try {
        final controller = webView?.webViewController;
        if (controller != null) {
          await controller
              .evaluateJavascript(
                source: '''
            document.querySelectorAll('video,audio').forEach(function(m) {
              try { m.pause(); m.removeAttribute('src'); m.load(); } catch(e) {}
            });
          ''',
              )
              .timeout(const Duration(seconds: 1));
        }
        await webView?.dispose().timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _log('Headless WebView dispose timed out - abandoning');
      } catch (e) {
        _log('Error during disposal: $e');
      }
    }
  }

  Future<void> dispose() async {
    await cancel();

    // Dispose Amri extractor
    await _amriExtractor?.dispose();
    _amriExtractor = null;
  }
}
