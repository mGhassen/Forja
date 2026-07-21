import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/features/anime/catalog/anime_browser_embed.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/webview/forja_in_app_webview.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shell/shell_bus.dart';

const _kUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

const _kAutoplayJs = r'''
(function () {
  function clickPlay() {
    var sels = [
      'video',
      'button.vjs-big-play-button',
      '.jw-icon-display',
      '.plyr__control--overlaid',
      '#big_play_button',
      '[aria-label="Play"]',
      'button[title="Play"]'
    ];
    for (var i = 0; i < sels.length; i++) {
      try {
        var nodes = document.querySelectorAll(sels[i]);
        for (var j = 0; j < nodes.length; j++) {
          var el = nodes[j];
          if (el.tagName === 'VIDEO') {
            el.setAttribute('autoplay', '');
            el.muted = false;
            var p = el.play();
            if (p && p.catch) {
              p.catch(function () {
                el.muted = true;
                el.play().catch(function () {});
              });
            }
          } else if (typeof el.click === 'function') {
            el.click();
          }
        }
      } catch (_) {}
    }
  }
  clickPlay();
  setTimeout(clickPlay, 1500);
})();
''';

const _kStopMediaJs = r'''
(function () {
  document.querySelectorAll('video,audio').forEach(function (el) {
    try {
      el.pause();
      el.muted = true;
      el.removeAttribute('src');
      while (el.firstChild) el.removeChild(el.firstChild);
      el.load();
    } catch (_) {}
  });
  document.querySelectorAll('iframe').forEach(function (frame) {
    try { frame.src = 'about:blank'; } catch (_) {}
  });
})();
''';

String _wrapperHtml(String embedUrl) {
  final safe = embedUrl
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;');
  return '''<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="referrer" content="unsafe-url">
<title>player</title>
<style>
html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
iframe{border:0;width:100%;height:100%;display:block}
</style>
</head><body>
<iframe id="p" src="$safe" allow="autoplay; fullscreen; encrypted-media" allowfullscreen referrerpolicy="unsafe-url"></iframe>
<script>
(function () {
  function ready() {
    try { window.flutter_inappwebview.callHandler('embedReady'); } catch (_) {}
  }
  var f = document.getElementById('p');
  if (f) f.addEventListener('load', ready);
  setTimeout(ready, 1500);
})();
</script>
</body></html>''';
}

/// Opens Megaplay / VidNest (etc.) in a WebView — same JS player as the browser.
Future<T?> openAnimeEmbedPlayer<T>({
  required BuildContext context,
  required AnimeBrowserEmbed embed,
  required String title,
  String? subtitle,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(
      builder: (_) => AnimeEmbedPlayerScreen(
        embed: embed,
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
}

class AnimeEmbedPlayerScreen extends StatefulWidget {
  const AnimeEmbedPlayerScreen({
    super.key,
    required this.embed,
    required this.title,
    this.subtitle,
  });

  final AnimeBrowserEmbed embed;
  final String title;
  final String? subtitle;

  @override
  State<AnimeEmbedPlayerScreen> createState() => _AnimeEmbedPlayerScreenState();
}

class _AnimeEmbedPlayerScreenState extends State<AnimeEmbedPlayerScreen> {
  bool _loading = true;
  bool _exiting = false;
  bool _leftSurface = false;
  Timer? _loadingWatchdog;
  InAppWebViewController? _webViewController;
  InAppWebViewInitialData? _initialData;
  URLRequest? _initialUrlRequest;
  late final InAppWebViewSettings _initialSettings;
  late final UnmodifiableListView<UserScript> _initialUserScripts;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'anime-embed-back');

  bool get _tvFocus =>
      ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;

  bool get _mainFrame => widget.embed.loadInMainFrame;

  void _leaveSurfaceOnce() {
    if (_leftSurface) return;
    _leftSurface = true;
    ShellBus.leavePlayerSurface();
  }

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    final referer = widget.embed.referer.endsWith('/')
        ? widget.embed.referer
        : '${widget.embed.referer}/';
    _initialUserScripts = UnmodifiableListView([
      UserScript(
        source: _kAutoplayJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ),
    ]);
    if (_mainFrame) {
      _initialUrlRequest = URLRequest(
        url: WebUri(widget.embed.url),
        headers: {'Referer': referer},
      );
    } else {
      _initialData = InAppWebViewInitialData(
        data: _wrapperHtml(widget.embed.url),
        baseUrl: WebUri(referer),
        historyUrl: WebUri(referer),
        mimeType: 'text/html',
        encoding: 'utf-8',
      );
    }
    _initialSettings = InAppWebViewSettings(
      userAgent: _kUa,
      domStorageEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      javaScriptEnabled: true,
      disableDefaultErrorPage: true,
      allowsPictureInPictureMediaPlayback: false,
      iframeAllow: 'autoplay; fullscreen; encrypted-media',
      iframeAllowFullscreen: true,
      useShouldOverrideUrlLoading: true,
      supportMultipleWindows: false,
      javaScriptCanOpenWindowsAutomatically: false,
    );
    _loadingWatchdog = Timer(const Duration(seconds: 2), _clearLoading);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tvFocus) return;
      if (_backFocusNode.canRequestFocus) _backFocusNode.requestFocus();
    });
  }

  void _clearLoading() {
    if (!mounted || !_loading) return;
    setState(() => _loading = false);
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    _loadingWatchdog?.cancel();
    try {
      await _webViewController?.evaluateJavascript(source: _kStopMediaJs);
    } catch (_) {}
    try {
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
    } catch (_) {}
    _leaveSurfaceOnce();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _loadingWatchdog?.cancel();
    _backFocusNode.dispose();
    _leaveSurfaceOnce();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle?.trim();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_exit());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: const Color(0xFF141414),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      _chromeTopPadding(context),
                      8,
                      6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          focusNode: _backFocusNode,
                          tooltip: 'Back',
                          onPressed: () => unawaited(_exit()),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                sub != null && sub.isNotEmpty
                                    ? '${widget.embed.label} · $sub'
                                    : widget.embed.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ForjaShellColors.brandGreen
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Web player',
                            style: TextStyle(
                              color: ForjaShellColors.brandGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ForjaInAppWebView(
                        initialData: _initialData,
                        initialUrlRequest: _initialUrlRequest,
                        initialUserScripts: _initialUserScripts,
                        initialSettings: _initialSettings,
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                          controller.addJavaScriptHandler(
                            handlerName: 'embedReady',
                            callback: (_) => _clearLoading(),
                          );
                        },
                        onLoadStop: (ctrl, _) async {
                          if (_exiting) return;
                          _clearLoading();
                          try {
                            await ctrl.evaluateJavascript(source: _kAutoplayJs);
                          } catch (_) {}
                        },
                        shouldOverrideUrlLoading: (ctrl, action) async {
                          final url = action.request.url?.toString() ?? '';
                          if (url.isEmpty ||
                              url.startsWith('about:') ||
                              url.startsWith('data:') ||
                              url.startsWith('blob:')) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          // Full watch pages (anikoto.cz) load third-party player
                          // iframes + CDNs — do not host-restrict like Megaplay embeds.
                          if (_mainFrame) {
                            final scheme =
                                Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
                            if (scheme == 'http' || scheme == 'https') {
                              return NavigationActionPolicy.ALLOW;
                            }
                            return NavigationActionPolicy.CANCEL;
                          }
                          final host =
                              Uri.tryParse(url)?.host.toLowerCase() ?? '';
                          final allowed = <String>{
                            Uri.tryParse(widget.embed.url)
                                    ?.host
                                    .toLowerCase() ??
                                '',
                            Uri.tryParse(widget.embed.referer)
                                    ?.host
                                    .toLowerCase() ??
                                '',
                            Uri.tryParse(widget.embed.origin)
                                    ?.host
                                    .toLowerCase() ??
                                '',
                          }.where((h) => h.isNotEmpty);
                          for (final h in allowed) {
                            if (host == h || host.endsWith('.$h')) {
                              return NavigationActionPolicy.ALLOW;
                            }
                          }
                          if (host.contains('nekostream') ||
                              host.contains('mewstream') ||
                              host.contains('vidnest') ||
                              host.contains('megaplay') ||
                              host.contains('vidwish') ||
                              host.contains('ibyteimg') ||
                              host.contains('watching.onl')) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          return NavigationActionPolicy.CANCEL;
                        },
                      ),
                      if (_loading)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: ForjaShellColors.brandGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            DesktopWindowChrome.overlayDragStrip(),
          ],
        ),
      ),
    );
  }

  /// Root-navigator route sits above [DesktopWindowChrome.wrapShell], so
  /// [SafeArea] alone does not clear macOS traffic lights.
  double _chromeTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 6;
    }
    return MediaQuery.paddingOf(context).top + 6;
  }
}
