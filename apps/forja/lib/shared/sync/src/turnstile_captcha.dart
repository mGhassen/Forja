import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';
import 'package:forja/shared/sync/src/forja_captcha.dart';
import 'package:forja/shared/theme/app_theme.dart';
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
/// Renders the standard Cloudflare widget at 300×65 with its native thin border
/// — no rim crop (cropping clipped edges and left a thick white L).
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

  /// Cloudflare "normal" widget is 300×65 when interaction is required.
  static const _widgetWidth = 300.0;
  static const _widgetHeight = 65.0;

  /// Windows WebView2 keeps an opaque surface even when
  /// [InAppWebViewSettings.transparentBackground] is true (see
  /// [patchWindowsWebViewSettings]); page CSS must paint a solid color there.
  static bool get _needsOpaquePageBg => !kIsWeb && Platform.isWindows;

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

  static String get _pageBgCss {
    if (!_needsOpaquePageBg) return 'transparent';
    final argb = AppTheme.appBackground.toARGB32();
    final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#$hex';
  }

  String get _html {
    final siteKeyJson = jsonEncode(ForjaCaptcha.siteKey);
    final pageBg = _pageBgCss;
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
      width: ${_widgetWidth.toInt()}px;
      height: ${_widgetHeight.toInt()}px;
      background: $pageBg;
      overflow: hidden;
      line-height: 0;
    }
    #cf-turnstile {
      display: block;
      width: ${_widgetWidth.toInt()}px;
      height: ${_widgetHeight.toInt()}px;
      line-height: 0;
    }
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
        transparentBackground: true,
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

    // Same element tree whether visible or not — swapping to a different
    // parent would recreate the WebView and drop the Turnstile session.
    return Offstage(
      offstage: _tokenReady,
      child: Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: _widgetHeight,
            width: _widgetWidth,
            child: _buildWebView(normalized),
          ),
        ),
      ),
    );
  }
}
