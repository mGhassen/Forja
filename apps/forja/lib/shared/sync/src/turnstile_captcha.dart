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
///
/// Uses Turnstile `appearance: interaction-only` so the grey widget plate stays
/// hidden unless Cloudflare needs a click. After a silent token, the slot
/// collapses; the WebView stays alive offstage for expire / refresh.
///
/// Cloudflare paints a light rim inside its iframe (not styleable). We crop a
/// few pixels on every side in HTML and again in Flutter so that rim never
/// reaches the form.
class TurnstileCaptcha extends StatefulWidget {
  const TurnstileCaptcha({
    super.key,
    required this.onToken,
    this.topPadding = 18,
  });

  final ValueChanged<String?> onToken;

  /// Applied only while the challenge slot is visible (not after silent token).
  final double topPadding;

  @override
  State<TurnstileCaptcha> createState() => _TurnstileCaptchaState();
}

class _TurnstileCaptchaState extends State<TurnstileCaptcha> {
  static const _handlerName = 'turnstileToken';

  /// Cloudflare "normal" widget is 300×65 before rim crop.
  static const _srcWidth = 300.0;
  static const _srcHeight = 65.0;

  /// Pixels trimmed from each edge (CF light rim + WKWebView fringe).
  static const _rimCrop = 4.0;

  static const _viewWidth = _srcWidth - _rimCrop * 2;
  static const _viewHeight = _srcHeight - _rimCrop * 2;

  /// Match CF dark-theme plate so any leftover hairline is dark, not white.
  static const _plateBg = '#232323';

  /// True after a usable token arrives; form slot collapses (no grey plate).
  bool _tokenReady = false;

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
    final crop = _rimCrop.toInt();
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
      width: ${_srcWidth.toInt()}px;
      height: ${_srcHeight.toInt()}px;
      background: $_plateBg;
      overflow: hidden;
      line-height: 0;
    }
    .cf-outer {
      overflow: hidden;
      width: ${_viewWidth.toInt()}px;
      height: ${_viewHeight.toInt()}px;
      line-height: 0;
    }
    .cf-inner {
      margin: -${crop}px;
      line-height: 0;
    }
    #cf-turnstile {
      display: block;
      width: ${_srcWidth.toInt()}px;
      height: ${_srcHeight.toInt()}px;
      overflow: hidden;
      line-height: 0;
    }
    #cf-turnstile iframe {
      border: 0 !important;
      outline: none !important;
    }
  </style>
</head>
<body>
  <div class="cf-outer">
    <div class="cf-inner">
      <div id="cf-turnstile"></div>
    </div>
  </div>
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
        size: 'normal',
        appearance: 'interaction-only',
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

  void _handleToken(String? token) {
    final ready = token != null && token.isNotEmpty;
    if (mounted && _tokenReady != ready) {
      setState(() => _tokenReady = ready);
    }
    widget.onToken(token);
  }

  Widget _buildWebView(String baseUrl) {
    return ForjaInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        supportZoom: false,
        disableHorizontalScroll: true,
        disableVerticalScroll: true,
        // Opaque host — transparent macOS/WebView2 edges read as a white rim.
        transparentBackground: false,
      ),
      initialData: InAppWebViewInitialData(
        data: _html,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri(baseUrl),
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: _handlerName,
          callback: (args) {
            final raw = args.isEmpty ? null : args.first;
            final token = raw is String && raw.isNotEmpty ? raw : null;
            _handleToken(token);
            return null;
          },
        );
      },
    );
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
      final host = uri.host;
      final useHttps = host != '127.0.0.1' &&
          host != 'localhost' &&
          uri.scheme == 'http';
      final fixed = useHttps ? uri.replace(scheme: 'https') : uri;
      final s = fixed.toString();
      return s.endsWith('/') ? s : '$s/';
    }();

    // Flutter crop mirrors the HTML rim crop — WKWebView overflow:hidden alone
    // still left a white L on the trailing edges.
    final captcha = SizedBox(
      width: _viewWidth,
      height: _viewHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: _srcWidth,
          maxWidth: _srcWidth,
          minHeight: _srcHeight,
          maxHeight: _srcHeight,
          child: SizedBox(
            width: _srcWidth,
            height: _srcHeight,
            child: _buildWebView(normalized),
          ),
        ),
      ),
    );

    // Same element tree whether visible or not — swapping to a different
    // parent would recreate the WebView and drop the Turnstile session.
    return Offstage(
      offstage: _tokenReady,
      child: Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: Align(
          alignment: Alignment.centerLeft,
          child: captcha,
        ),
      ),
    );
  }
}
