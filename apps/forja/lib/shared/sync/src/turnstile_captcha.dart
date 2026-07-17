import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';
import 'package:forja/shared/sync/src/forja_captcha.dart';
import 'package:forja/shared/webview/forja_webview.dart';

/// Compact Turnstile challenge for desktop email/password sign-in.
///
/// Renders nothing when [ForjaCaptcha.isConfigured] is false. Remount with a
/// new [Key] after a failed auth attempt to mint a fresh token.
class TurnstileCaptcha extends StatefulWidget {
  const TurnstileCaptcha({
    super.key,
    required this.onToken,
  });

  final ValueChanged<String?> onToken;

  @override
  State<TurnstileCaptcha> createState() => _TurnstileCaptchaState();
}

class _TurnstileCaptchaState extends State<TurnstileCaptcha> {
  static const _handlerName = 'turnstileToken';
  static const _widgetHeight = 72.0;

  @override
  void initState() {
    super.initState();
    if (!ForjaCaptcha.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onToken(null);
      });
    }
  }

  String get _html {
    final siteKeyJson = jsonEncode(ForjaCaptcha.siteKey);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" async defer></script>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: #0a0a0a;
      overflow: hidden;
    }
    #cf-turnstile { display: inline-block; }
  </style>
</head>
<body>
  <div id="cf-turnstile"></div>
  <script>
    const siteKey = $siteKeyJson;
    function postToken(token) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$_handlerName', token);
      }
    }
    function renderWhenReady() {
      if (typeof turnstile === 'undefined') {
        setTimeout(renderWhenReady, 40);
        return;
      }
      turnstile.render('#cf-turnstile', {
        sitekey: siteKey,
        theme: 'dark',
        callback: function (token) { postToken(token); },
        'expired-callback': function () { postToken(null); },
        'error-callback': function () { postToken(null); }
      });
    }
    renderWhenReady();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (!ForjaCaptcha.isConfigured) return const SizedBox.shrink();

    final base = DesktopBrowserAuth.webUrl;
    final uri = Uri.tryParse(base);
    final normalized = () {
      if (uri == null || !uri.hasScheme) {
        return base.endsWith('/') ? base : '$base/';
      }
      // Turnstile host checks expect the portal origin; prefer https off-loopback.
      final host = uri.host;
      final useHttps = host != '127.0.0.1' &&
          host != 'localhost' &&
          uri.scheme == 'http';
      final fixed = useHttps ? uri.replace(scheme: 'https') : uri;
      final s = fixed.toString();
      return s.endsWith('/') ? s : '$s/';
    }();

    return SizedBox(
      height: _widgetHeight,
      width: double.infinity,
      child: ForjaInAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          supportZoom: false,
          disableHorizontalScroll: true,
          disableVerticalScroll: true,
          transparentBackground: false,
          // Avoid Windows WebView2 create-time transparent bug path.
        ),
        initialData: InAppWebViewInitialData(
          data: _html,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri(normalized),
        ),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: _handlerName,
            callback: (args) {
              final raw = args.isEmpty ? null : args.first;
              final token = raw is String && raw.isNotEmpty ? raw : null;
              widget.onToken(token);
              return null;
            },
          );
        },
      ),
    );
  }
}
