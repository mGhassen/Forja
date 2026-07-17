import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview.dart';

/// Official Miruro domains (miruro no Kuon status page).
///
/// Prefer `.tv` first — it matches the public site users open in a browser;
/// `.to` is still tried as a mirror.
class MiruroDomains {
  MiruroDomains._();

  static const List<String> official = [
    'https://www.miruro.tv',
    'https://www.miruro.to',
    'https://www.miruro.bz',
    'https://www.miruro.ru',
  ];

  static const String primary = 'https://www.miruro.tv';
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

  ForjaHeadlessInAppWebView? _web;
  InAppWebViewController? _controller;
  String? _sessionOrigin;
  Future<void>? _boot;
  Completer<void>? _bootReady;
  Future<void> _chain = Future.value();
  int _epoch = 0;

  /// Drop queued/in-flight pipe fetches (player exit, provider switch).
  void cancelPending() {
    _epoch++;
    _chain = Future.value();
    final ready = _bootReady;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('MiruroPipe cancelled'));
    }
    unawaited(_disposeWebView(keepChain: false));
  }

  Future<({int status, String body, String? xObf})?> get(String pipeUrl) {
    final completer = Completer<({int status, String body, String? xObf})?>();
    final epoch = _epoch;
    _chain = _chain.then((_) async {
      if (epoch != _epoch) {
        completer.complete(null);
        return;
      }
      try {
        completer.complete(await _getUnlocked(pipeUrl, epoch: epoch));
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
    final bootEpoch = _epoch;
    if (_sessionOrigin != null && _sessionOrigin != origin) {
      await _disposeWebView(keepChain: true);
    }
    _sessionOrigin = origin;

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
        // Keep cookies across challenge → app navigations in this session.
        cacheEnabled: true,
        clearCache: false,
        incognito: false,
      ),
      onWebViewCreated: (c) => _controller = c,
      onLoadStop: (_, url) {
        if (kDebugMode) debugPrint('[MiruroPipe] loadStop $url');
        markReady();
      },
      onProgressChanged: (_, progress) {
        // CF challenge pages sometimes stall before onLoadStop; 90% is enough
        // to start same-origin fetch (cookies usually already set).
        if (progress >= 90) markReady();
      },
      onReceivedError: (_, request, error) {
        if (kDebugMode) {
          debugPrint(
            '[MiruroPipe] load error ${request.url}: '
            '${error.description} (${error.type})',
          );
        }
        // Main-frame failure — unblock the waiter so domain failover can run.
        if (request.isForMainFrame ?? true) markReady();
      },
    );
    try {
      await _web!.run();
      if (bootEpoch != _epoch) {
        throw StateError('MiruroPipe cancelled');
      }
      await ready.future.timeout(const Duration(seconds: 20));
      // Let Turnstile / managed challenge settle cookies before pipe fetch.
      await _waitForCfClearance(epoch: bootEpoch, origin: origin);
      if (bootEpoch != _epoch) {
        throw StateError('MiruroPipe cancelled');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MiruroPipe] boot failed ($origin): $e');
      await _disposeWebView(keepChain: true);
      rethrow;
    } finally {
      if (identical(_bootReady, ready)) _bootReady = null;
    }
  }

  /// Poll until the CF interstitial is gone (or timeout).
  Future<void> _waitForCfClearance({
    required int epoch,
    required String origin,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (epoch != _epoch) return;
      try {
        final res = await controller.callAsyncJavaScript(
          functionBody: '''
            const t = (document.title || '').toLowerCase();
            const b = (document.body && document.body.innerText) || '';
            const blocked =
              t.includes('just a moment') ||
              t.includes('attention required') ||
              b.includes('Checking your browser') ||
              b.includes('Enable JavaScript and cookies');
            return { blocked: blocked, title: document.title || '' };
          ''',
        );
        final value = res?.value;
        if (value is Map && value['blocked'] != true) {
          if (kDebugMode) {
            debugPrint('[MiruroPipe] CF clear on $origin (${value['title']})');
          }
          return;
        }
      } catch (_) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (kDebugMode) {
      debugPrint('[MiruroPipe] CF wait timed out on $origin — trying pipe anyway');
    }
  }

  Future<({int status, String body, String? xObf})?> _getUnlocked(
    String pipeUrl, {
    bool allowRetry = true,
    required int epoch,
  }) async {
    if (epoch != _epoch) return null;

    final preferred = Uri.parse(pipeUrl).origin;
    final origins = <String>[
      preferred,
      ...MiruroDomains.official.where((o) => o != preferred),
    ];

    Object? lastError;
    for (final origin in origins) {
      if (epoch != _epoch) return null;
      final rewritten = _rewritePipeOrigin(pipeUrl, preferred, origin);
      try {
        await _ensureBooted(origin);
      } catch (e) {
        lastError = e;
        continue;
      }
      if (epoch != _epoch) return null;
      final controller = _controller;
      if (controller == null) continue;

      final hit = await _fetchPipe(controller, rewritten, origin, epoch);
      if (hit == null) continue;
      if (epoch != _epoch) return null;

      if (allowRetry &&
          hit.status == 403 &&
          hit.body.toLowerCase().contains('cloudflare')) {
        await _disposeWebView(keepChain: true);
        if (epoch != _epoch) return null;
        try {
          await _ensureBooted(origin);
        } catch (e) {
          lastError = e;
          continue;
        }
        return _getUnlocked(rewritten, allowRetry: false, epoch: epoch);
      }
      return hit;
    }

    if (kDebugMode && lastError != null) {
      debugPrint('[MiruroPipe] all domains failed; last=$lastError');
    }
    return null;
  }

  Future<({int status, String body, String? xObf})?> _fetchPipe(
    InAppWebViewController controller,
    String pipeUrl,
    String origin,
    int epoch,
  ) async {
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
    if (epoch != _epoch) return null;
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
    if (kDebugMode) {
      final err = value['error']?.toString();
      debugPrint(
        '[MiruroPipe] pipe status=${status.toInt()} '
        'len=${body.length}${err != null && err.isNotEmpty ? ' err=$err' : ''}',
      );
    }
    return (status: status.toInt(), body: body, xObf: xObf);
  }

  static String _rewritePipeOrigin(String pipeUrl, String from, String to) {
    if (from == to) return pipeUrl;
    if (!pipeUrl.startsWith(from)) return pipeUrl;
    return '$to${pipeUrl.substring(from.length)}';
  }

  Future<void> _disposeWebView({bool keepChain = false}) async {
    final ready = _bootReady;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('MiruroPipe disposed'));
    }
    _bootReady = null;
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
    cancelPending();
    await _chain;
    await _disposeWebView();
  }
}

String miruroEncodePipeRequest(Map<String, dynamic> payload) {
  return base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
}
