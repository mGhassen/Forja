import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview.dart';

/// Browser-session transport for onlykdrama.shop (Cloudflare-gated).
///
/// Plain engine HTTP gets the CF interstitial; a headless WebView clears the
/// challenge then same-origin `fetch()`es with cookies (Miruro pattern).
class OnlyKDramaCfSession {
  OnlyKDramaCfSession._();
  static final OnlyKDramaCfSession instance = OnlyKDramaCfSession._();

  static const origin = 'https://onlykdrama.shop';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';

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
    final challenged =
        hit.status == 403 ||
        hit.status == 503 ||
        lower.contains('just a moment') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('challenge-platform');
    if (allowRetry && challenged) {
      await _disposeWebView();
      if (epoch != _epoch) return null;
      try {
        await _ensureBooted();
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

  Future<void> _ensureBooted() {
    if (_boot != null && _controller != null) return _boot!;
    _boot = _bootWebView();
    return _boot!;
  }

  Future<void> _bootWebView() async {
    final bootEpoch = _epoch;
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
      if (bootEpoch != _epoch) throw StateError('OnlyKDramaCf cancelled');
      await ready.future.timeout(const Duration(seconds: 25));
      await _waitForCfClearance(epoch: bootEpoch);
      if (bootEpoch != _epoch) throw StateError('OnlyKDramaCf cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('[OnlyKDramaCf] boot failed: $e');
      await _disposeWebView();
      rethrow;
    } finally {
      if (identical(_bootReady, ready)) _bootReady = null;
    }
  }

  Future<void> _waitForCfClearance({required int epoch}) async {
    final controller = _controller;
    if (controller == null) return;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      if (epoch != _epoch) return;
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
              b.includes('Attention Required');
            return { blocked: blocked, title: title };
          ''',
        );
        final value = res?.value;
        if (value is Map && value['blocked'] != true) {
          final title = value['title']?.toString() ?? '';
          if (title.trim().isNotEmpty) {
            if (kDebugMode) {
              debugPrint('[OnlyKDramaCf] CF clear ($title)');
            }
            return;
          }
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (kDebugMode) {
      debugPrint('[OnlyKDramaCf] CF wait timed out — continuing anyway');
    }
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
