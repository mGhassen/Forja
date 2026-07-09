import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Official Miruro domains (miruro no Kuon status page).
class MiruroDomains {
  MiruroDomains._();

  static const List<String> official = [
    'https://www.miruro.to',
    'https://www.miruro.bz',
    'https://www.miruro.ru',
    'https://www.miruro.tv',
  ];

  static const String primary = 'https://www.miruro.to';
}

/// Browser-session transport for Miruro's `secure/pipe` API.
///
/// Miruro sits behind Cloudflare and rejects plain HTTP clients (403 HTML).
/// A headless WebView on an official domain passes TLS / bot checks and can
/// `fetch()` the pipe same-origin with cookies.
class MiruroPipeSession {
  MiruroPipeSession._();
  static final MiruroPipeSession instance = MiruroPipeSession._();

  static String get baseUrl => MiruroDomains.primary;

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  HeadlessInAppWebView? _web;
  InAppWebViewController? _controller;
  String? _sessionOrigin;
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

  Future<void> _ensureBooted(String origin) {
    if (_sessionOrigin == origin && _boot != null) return _boot!;
    _boot = _bootWebView(origin);
    return _boot!;
  }

  Future<void> _bootWebView(String origin) async {
    if (_sessionOrigin != null && _sessionOrigin != origin) {
      await _disposeWebView(keepChain: true);
    }
    _sessionOrigin = origin;

    final ready = Completer<void>();
    _web = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$origin/')),
      initialSize: const Size(1280, 720),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _ua,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (c) => _controller = c,
      onLoadStop: (_, _) {
        if (!ready.isCompleted) ready.complete();
      },
      onReceivedError: (_, _, _) {
        if (!ready.isCompleted) ready.complete();
      },
    );
    try {
      await _web!.run();
      await ready.future.timeout(const Duration(seconds: 35));
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      if (kDebugMode) debugPrint('[MiruroPipe] boot failed ($origin): $e');
      await _disposeWebView(keepChain: true);
      rethrow;
    }
  }

  Future<({int status, String body, String? xObf})?> _getUnlocked(
    String pipeUrl, {
    bool allowRetry = true,
  }) async {
    final origin = Uri.parse(pipeUrl).origin;
    await _ensureBooted(origin);
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
              'Referer': '$origin/',
              'Origin': '$origin',
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
      await _disposeWebView(keepChain: true);
      await _ensureBooted(origin);
      return _getUnlocked(pipeUrl, allowRetry: false);
    }
    return (status: code, body: body, xObf: xObf);
  }

  Future<void> _disposeWebView({bool keepChain = false}) async {
    try {
      await _web?.dispose();
    } catch (_) {}
    _web = null;
    _controller = null;
    _sessionOrigin = null;
    _boot = null;
    if (!keepChain) _chain = Future.value();
  }

  Future<void> dispose() async {
    await _chain;
    await _disposeWebView();
  }
}

String miruroEncodePipeRequest(Map<String, dynamic> payload) {
  return base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
}
