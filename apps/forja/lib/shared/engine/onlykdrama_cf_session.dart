import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Cloudflare transport for onlykdrama.shop.
///
/// Headless alone cannot clear this site's managed/Turnstile challenge
/// (stays on "Just a moment…" → every fetch 403). Unlock once with a real
/// on-screen WebView (auto or click), cookies land in [CookieManager], then
/// a headless session reuses them for same-origin `fetch()`.
class OnlyKDramaCfSession {
  OnlyKDramaCfSession._();
  static final OnlyKDramaCfSession instance = OnlyKDramaCfSession._();

  static const origin = 'https://onlykdrama.shop';
  static const _ua =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/18.2 Safari/605.1.15';

  ForjaHeadlessInAppWebView? _web;
  InAppWebViewController? _controller;
  Future<void>? _boot;
  Completer<void>? _bootReady;
  Future<void> _chain = Future.value();
  int _epoch = 0;

  static bool handles(Uri uri) {
    final h = uri.host.toLowerCase();
    return h == 'onlykdrama.shop' || h == 'www.onlykdrama.shop';
  }

  void cancelPending() {
    _epoch++;
    _chain = Future.value();
    final ready = _bootReady;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('OnlyKDramaCf cancelled'));
    }
    unawaited(_disposeWebView());
  }

  Future<({int status, String body, String url})?> fetch(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    String? body,
  }) {
    final completer = Completer<({int status, String body, String url})?>();
    final epoch = _epoch;
    _chain = _chain.then((_) async {
      if (epoch != _epoch) {
        completer.complete(null);
        return;
      }
      try {
        completer.complete(
          await _fetchUnlocked(
            url,
            method: method,
            headers: headers,
            body: body,
            epoch: epoch,
          ),
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[OnlyKDramaCf] fetch failed: $e\n$st');
        }
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<({int status, String body, String url})?> _fetchUnlocked(
    String url, {
    required String method,
    Map<String, String>? headers,
    String? body,
    required int epoch,
    bool allowRetry = true,
  }) async {
    if (epoch != _epoch) return null;
    try {
      await _ensureBooted();
    } catch (e) {
      if (kDebugMode) debugPrint('[OnlyKDramaCf] boot failed: $e');
      return null;
    }
    if (epoch != _epoch) return null;
    final controller = _controller;
    if (controller == null) return null;

    final hit = await _pageFetch(
      controller,
      url: url,
      method: method,
      headers: headers,
      body: body,
      epoch: epoch,
    );
    if (hit == null || epoch != _epoch) return null;

    final lower = hit.body.toLowerCase();
    final challenged = hit.status == 403 ||
        hit.status == 503 ||
        lower.contains('just a moment') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('challenge-platform');
    if (allowRetry && challenged) {
      await _disposeWebView();
      if (epoch != _epoch) return null;
      try {
        await _ensureBooted(forceUnlock: true);
      } catch (_) {
        return hit;
      }
      return _fetchUnlocked(
        url,
        method: method,
        headers: headers,
        body: body,
        epoch: epoch,
        allowRetry: false,
      );
    }
    return hit;
  }

  Future<void> _ensureBooted({bool forceUnlock = false}) {
    if (!forceUnlock && _boot != null && _controller != null) return _boot!;
    _boot = _bootWebView(forceUnlock: forceUnlock);
    return _boot!;
  }

  Future<void> _bootWebView({required bool forceUnlock}) async {
    final bootEpoch = _epoch;
    try {
      if (forceUnlock || !await _hasClearanceCookie()) {
        await _unlockViaVisibleWebView(epoch: bootEpoch);
      } else if (kDebugMode) {
        debugPrint('[OnlyKDramaCf] reusing cf_clearance cookie');
      }
      if (bootEpoch != _epoch) throw StateError('OnlyKDramaCf cancelled');
      await _startHeadless(epoch: bootEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('[OnlyKDramaCf] boot failed: $e');
      await _disposeWebView();
      rethrow;
    }
  }

  Future<bool> _hasClearanceCookie() async {
    try {
      final cookies =
          await CookieManager.instance().getCookies(url: WebUri(origin));
      return cookies.any(
        (c) => c.name == 'cf_clearance' && c.value.isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _unlockViaVisibleWebView({required int epoch}) async {
    final ctx = shellOverlayNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      throw StateError('OnlyKDramaCf: no UI context to unlock Cloudflare');
    }
    if (kDebugMode) {
      debugPrint('[OnlyKDramaCf] opening visible WebView to clear CF');
    }

    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) => _OnlyKDramaCfUnlockDialog(
        origin: origin,
        userAgent: _ua,
        onSuccess: () {
          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
        },
      ),
    );

    if (epoch != _epoch) throw StateError('OnlyKDramaCf cancelled');
    if (result != true) {
      throw StateError('OnlyKDramaCf: unlock dismissed or failed');
    }
  }

  Future<void> _startHeadless({required int epoch}) async {
    final ready = Completer<void>();
    _bootReady = ready;
    void markReady() {
      if (!ready.isCompleted) ready.complete();
    }

    _web = ForjaHeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$origin/')),
      initialSize: const Size(1280, 720),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _ua,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: true,
        cacheEnabled: true,
        clearCache: false,
        incognito: false,
      ),
      onWebViewCreated: (c) => _controller = c,
      onLoadStop: (_, url) {
        if (kDebugMode) debugPrint('[OnlyKDramaCf] loadStop $url');
        markReady();
      },
      onProgressChanged: (_, progress) {
        if (progress >= 100) markReady();
      },
      onReceivedError: (_, request, error) {
        if (kDebugMode) {
          debugPrint(
            '[OnlyKDramaCf] load error ${request.url}: '
            '${error.description} (${error.type})',
          );
        }
      },
    );

    try {
      await _web!.run();
      if (epoch != _epoch) throw StateError('OnlyKDramaCf cancelled');
      await ready.future.timeout(const Duration(seconds: 25));
      final cleared = await _waitForCfClearance(epoch: epoch);
      if (!cleared) {
        throw StateError(
          'OnlyKDramaCf: headless still challenged after unlock',
        );
      }
      if (epoch != _epoch) throw StateError('OnlyKDramaCf cancelled');
      if (kDebugMode) debugPrint('[OnlyKDramaCf] headless session ready');
    } finally {
      if (identical(_bootReady, ready)) _bootReady = null;
    }
  }

  /// Returns true only when challenge is gone. Does not soft-continue.
  Future<bool> _waitForCfClearance({required int epoch}) async {
    final controller = _controller;
    if (controller == null) return false;
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      if (epoch != _epoch) return false;
      try {
        final res = await controller.callAsyncJavaScript(
          functionBody: '''
            const title = document.title || '';
            const t = title.toLowerCase();
            const b = (document.body && document.body.innerText) || '';
            const blocked =
              !title.trim() ||
              t.includes('just a moment') ||
              t.includes('attention required') ||
              b.includes('Checking your browser') ||
              b.includes('Enable JavaScript and cookies') ||
              b.includes('Attention Required') ||
              b.includes('Verify you are human');
            return { blocked: blocked, title: title };
          ''',
        );
        final value = res?.value;
        if (value is Map &&
            value['blocked'] != true &&
            (value['title']?.toString() ?? '').trim().isNotEmpty) {
          if (kDebugMode) {
            debugPrint('[OnlyKDramaCf] CF clear (${value['title']})');
          }
          return true;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (kDebugMode) {
      debugPrint('[OnlyKDramaCf] CF wait timed out — failing closed');
    }
    return false;
  }

  Future<({int status, String body, String url})?> _pageFetch(
    InAppWebViewController controller, {
    required String url,
    required String method,
    Map<String, String>? headers,
    String? body,
    required int epoch,
  }) async {
    final headerMap = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      ...?headers,
    };
    final res = await controller.callAsyncJavaScript(
      functionBody: '''
        try {
          const init = {
            method: method,
            credentials: 'include',
            headers: headers,
            redirect: 'follow',
          };
          if (body && method !== 'GET' && method !== 'HEAD') {
            init.body = body;
          }
          const r = await fetch(url, init);
          const text = await r.text();
          return { status: r.status, body: text, url: r.url || url };
        } catch (e) {
          return { status: 0, body: '', url: url, error: String(e) };
        }
      ''',
      arguments: {
        'url': url,
        'method': method.toUpperCase(),
        'headers': headerMap,
        'body': body ?? '',
      },
    );
    if (epoch != _epoch) return null;
    if (res?.error != null) {
      if (kDebugMode) debugPrint('[OnlyKDramaCf] JS error: ${res!.error}');
      return null;
    }
    final value = res?.value;
    if (value is! Map) return null;
    final status = (value['status'] as num?)?.toInt() ?? 0;
    final text = value['body']?.toString() ?? '';
    final finalUrl = value['url']?.toString() ?? url;
    if (kDebugMode) {
      debugPrint(
        '[OnlyKDramaCf] $method $url → $status (${text.length} chars)',
      );
    }
    return (status: status, body: text, url: finalUrl);
  }

  Future<void> _disposeWebView() async {
    _boot = null;
    _controller = null;
    final web = _web;
    _web = null;
    if (web != null) {
      try {
        await web.dispose();
      } catch (_) {}
    }
  }
}

class _OnlyKDramaCfUnlockDialog extends StatefulWidget {
  const _OnlyKDramaCfUnlockDialog({
    required this.origin,
    required this.userAgent,
    required this.onSuccess,
  });

  final String origin;
  final String userAgent;
  final VoidCallback onSuccess;

  @override
  State<_OnlyKDramaCfUnlockDialog> createState() =>
      _OnlyKDramaCfUnlockDialogState();
}

class _OnlyKDramaCfUnlockDialogState extends State<_OnlyKDramaCfUnlockDialog> {
  InAppWebViewController? _controller;
  Timer? _poll;
  var _done = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPoll(InAppWebViewController controller) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted || _done) return;
      try {
        final res = await controller.callAsyncJavaScript(
          functionBody: '''
            const title = document.title || '';
            const t = title.toLowerCase();
            const b = (document.body && document.body.innerText) || '';
            const blocked =
              !title.trim() ||
              t.includes('just a moment') ||
              t.includes('attention required') ||
              b.includes('Checking your browser') ||
              b.includes('Enable JavaScript and cookies') ||
              b.includes('Attention Required') ||
              b.includes('Verify you are human');
            return { blocked: blocked, title: title };
          ''',
        );
        final value = res?.value;
        if (value is Map &&
            value['blocked'] != true &&
            (value['title']?.toString() ?? '').trim().isNotEmpty) {
          _done = true;
          _poll?.cancel();
          widget.onSuccess();
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('OnlyKDrama — Cloudflare'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Finish the check if asked (usually automatic). '
              'Unlocks OnlyKDrama for this session.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ForjaInAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri('${widget.origin}/'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    userAgent: widget.userAgent,
                    mediaPlaybackRequiresUserGesture: true,
                    allowsInlineMediaPlayback: true,
                    cacheEnabled: true,
                    clearCache: false,
                    incognito: false,
                  ),
                  onWebViewCreated: (c) {
                    _controller = c;
                    _startPoll(c);
                  },
                  onLoadStop: (_, _) {
                    final c = _controller;
                    if (c != null) _startPoll(c);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
