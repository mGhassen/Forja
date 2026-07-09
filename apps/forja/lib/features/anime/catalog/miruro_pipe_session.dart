import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Browser-session transport for Miruro's `secure/pipe` API.
///
/// Miruro sits behind Cloudflare and rejects plain HTTP clients (403 HTML).
/// A headless WebView on miruro.tv passes the TLS / bot checks and can
/// `fetch()` the pipe from same-origin with cookies.
class MiruroPipeSession {
  MiruroPipeSession._();
  static final MiruroPipeSession instance = MiruroPipeSession._();

  static const String baseUrl = 'https://www.miruro.tv';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  HeadlessInAppWebView? _web;
  InAppWebViewController? _controller;
  Future<void>? _boot;
  Future<void> _chain = Future.value();

  Future<({int status, String body, String? xObf})?> get(String pipeUrl) {
    final completer = Completer<({int status, String body, String? xObf})?>();
    _chain = _chain.then((_) async {
      try {
        completer.complete(await _getUnlocked(pipeUrl));
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[MiruroPipe] fetch failed: $e\n$st');
        }
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<void> _ensureBooted() {
    _boot ??= _bootWebView();
    return _boot!;
  }

  Future<void> _bootWebView() async {
    final ready = Completer<void>();
    _web = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$baseUrl/')),
      initialSize: const Size(1280, 720),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _ua,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (c) => _controller = c,
      onLoadStop: (_, __) {
        if (!ready.isCompleted) ready.complete();
      },
      onReceivedError: (_, __, ___) {
        if (!ready.isCompleted) ready.complete();
      },
    );
    try {
      await _web!.run();
      await ready.future.timeout(const Duration(seconds: 35));
      // Let Cloudflare / SPA settle before the first pipe call.
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      if (kDebugMode) debugPrint('[MiruroPipe] boot failed: $e');
      await _disposeWebView();
      rethrow;
    }
  }

  Future<({int status, String body, String? xObf})?> _getUnlocked(
    String pipeUrl, {
    bool allowRetry = true,
  }) async {
    await _ensureBooted();
    final controller = _controller;
    if (controller == null) return null;

    final res = await controller.callAsyncJavaScript(
      functionBody: '''
        try {
          const r = await fetch(pipeUrl, {
            method: 'GET',
            credentials: 'include',
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Referer': '$baseUrl/',
              'Origin': '$baseUrl',
            },
          });
          const body = await r.text();
          return {
            status: r.status,
            body: body,
            xObf: r.headers.get('x-obfuscated') || '',
          };
        } catch (e) {
          return { status: 0, body: '', xObf: '', error: String(e) };
        }
      ''',
      arguments: {'pipeUrl': pipeUrl},
    );
    if (res?.error != null) {
      if (kDebugMode) debugPrint('[MiruroPipe] JS error: ${res!.error}');
      return null;
    }
    final value = res?.value;
    if (value is! Map) return null;
    final status = value['status'];
    final body = value['body']?.toString() ?? '';
    final xObfRaw = value['xObf']?.toString();
    final xObf = (xObfRaw == null || xObfRaw.isEmpty) ? null : xObfRaw;
    if (status is! num) return null;
    final code = status.toInt();
    if (allowRetry &&
        code == 403 &&
        body.toLowerCase().contains('cloudflare')) {
      await _disposeWebView();
      await _ensureBooted();
      return _getUnlocked(pipeUrl, allowRetry: false);
    }
    return (status: code, body: body, xObf: xObf);
  }

  Future<void> _disposeWebView() async {
    try {
      await _web?.dispose();
    } catch (_) {}
    _web = null;
    _controller = null;
    _boot = null;
  }

  Future<void> dispose() async {
    await _chain;
    await _disposeWebView();
  }
}

String miruroEncodePipeRequest(Map<String, dynamic> payload) {
  return base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
}
