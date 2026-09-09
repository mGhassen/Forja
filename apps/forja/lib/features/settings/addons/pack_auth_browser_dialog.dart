import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/webview/forja_in_app_webview.dart';
import 'package:url_launcher/url_launcher.dart';

/// Host browser auth for pack Connected Services (`flow: "browser"`).
/// Opens [url], harvests session cookies / localStorage keys from [capture],
/// returns fields for pack `auth_login` (method: browser).
class PackAuthBrowserDialog extends StatefulWidget {
  const PackAuthBrowserDialog({
    super.key,
    required this.title,
    required this.url,
    this.hint = '',
    this.capture = const {},
  });

  final String title;
  final String url;
  final String hint;
  final Map<String, dynamic> capture;

  @override
  State<PackAuthBrowserDialog> createState() => _PackAuthBrowserDialogState();
}

class _PackAuthBrowserDialogState extends State<PackAuthBrowserDialog> {
  InAppWebViewController? _controller;
  Timer? _poll;
  var _capturing = false;
  var _status = 'Waiting for sign-in…';

  List<String> get _cookieNames {
    final raw = widget.capture['cookieNames'];
    if (raw is! List) return const ['token'];
    return [
      for (final e in raw)
        if (e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  }

  List<String> get _localStorageKeys {
    final raw = widget.capture['localStorageKeys'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  }

  List<String> get _originHosts {
    final raw = widget.capture['originHosts'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e.toString().trim().isNotEmpty) e.toString().trim().toLowerCase(),
    ];
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tryCapture());
    });
  }

  bool _hostAllowed(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return false;
    final hosts = _originHosts;
    if (hosts.isEmpty) return true;
    final h = uri.host.toLowerCase();
    return hosts.any((want) => h == want || h.endsWith('.$want'));
  }

  Future<void> _tryCapture() async {
    if (_capturing || !mounted) return;
    final c = _controller;
    if (c == null) return;
    _capturing = true;
    try {
      final url = await c.getUrl();
      if (!_hostAllowed(url)) return;

      String? sessionId;
      String? label;

      final cookieMgr = CookieManager.instance();
      for (final origin in {
        'https://shahid.mbc.net',
        'https://www.shahid.mbc.net',
        if (url != null) url.toString(),
      }) {
        final cookies = await cookieMgr.getCookies(url: WebUri(origin));
        for (final cookie in cookies) {
          final name = cookie.name;
          if (!_cookieNames.contains(name)) continue;
          final v = cookie.value.trim();
          if (v.length >= 8) {
            sessionId = v;
            break;
          }
        }
        if (sessionId != null) break;
      }

      if (_localStorageKeys.isNotEmpty) {
        final raw = await c.evaluateJavascript(
          source:
              '''
            (function() {
              var out = {};
              var keys = ${jsonEncode(_localStorageKeys)};
              for (var i = 0; i < keys.length; i++) {
                try { out[keys[i]] = localStorage.getItem(keys[i]); } catch (e) {}
              }
              try { out.__cookie = document.cookie || ''; } catch (e) {}
              return JSON.stringify(out);
            })();
          ''',
        );
        final decoded = _decodeJsJson(raw);
        if (decoded != null) {
          if (sessionId == null || sessionId.isEmpty) {
            sessionId =
                _sessionFromPersist(decoded) ??
                _sessionFromCookieHeader(
                  (decoded['__cookie'] ?? '').toString(),
                );
          }
          label = _labelFromPersist(decoded);
        }
      }

      if (sessionId == null || sessionId.trim().length < 8) return;
      if (!mounted) return;
      _poll?.cancel();
      setState(() => _status = 'Importing session…');
      final out = <String, String>{'sessionId': sessionId.trim()};
      final who = label?.trim();
      if (who != null && who.isNotEmpty) out['label'] = who;
      Navigator.of(context).pop(out);
    } catch (e) {
      debugPrint('[PackAuthBrowser] capture: $e');
    } finally {
      _capturing = false;
    }
  }

  Map<String, dynamic>? _decodeJsJson(dynamic raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      try {
        s = jsonDecode(s) as String;
      } catch (_) {}
    }
    try {
      final v = jsonDecode(s);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  String? _sessionFromCookieHeader(String header) {
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length < 2) continue;
      if (!_cookieNames.contains(kv.first.trim())) continue;
      final v = kv.sublist(1).join('=').trim();
      if (v.length >= 8) return v;
    }
    return null;
  }

  String? _sessionFromPersist(Map<String, dynamic> decoded) {
    for (final key in _localStorageKeys) {
      final raw = decoded[key];
      if (raw == null) continue;
      try {
        final outer = jsonDecode(raw.toString());
        if (outer is! Map) continue;
        final userRaw = outer['user'];
        if (userRaw == null) continue;
        final user = userRaw is String ? jsonDecode(userRaw) : userRaw;
        if (user is! Map) continue;
        final sid = (user['sessionId'] ?? user['token'] ?? '')
            .toString()
            .trim();
        if (sid.length >= 8) return sid;
      } catch (_) {}
    }
    return null;
  }

  String? _labelFromPersist(Map<String, dynamic> decoded) {
    for (final key in _localStorageKeys) {
      final raw = decoded[key];
      if (raw == null) continue;
      try {
        final outer = jsonDecode(raw.toString());
        if (outer is! Map) continue;
        final userRaw = outer['user'];
        if (userRaw == null) continue;
        final user = userRaw is String ? jsonDecode(userRaw) : userRaw;
        if (user is! Map) continue;
        final email =
            (user['email'] ??
                    user['communicationEmail'] ??
                    user['userName'] ??
                    '')
                .toString()
                .trim();
        if (email.isNotEmpty) return email;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: size.width.clamp(320, 720),
        height: size.height.clamp(420, 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open in browser',
                    onPressed: _openExternal,
                    icon: const Icon(Icons.open_in_browser),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (widget.hint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  widget.hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ForjaShellColors.textSecondary,
                  ),
                ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ForjaInAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    sharedCookiesEnabled: true,
                    userAgent:
                        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/120.0.0.0 Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                    _startPoll();
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _status = _hostAllowed(url)
                          ? 'Signed-in page loaded — importing…'
                          : 'Complete sign-in in the page…';
                    });
                    unawaited(_tryCapture());
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ForjaShellColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
