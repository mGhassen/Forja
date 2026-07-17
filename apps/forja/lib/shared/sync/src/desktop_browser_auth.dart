import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the Forja web portal login and captures the session via a localhost
/// callback (desktop OAuth-style redirect).
class DesktopBrowserAuth {
  DesktopBrowserAuth._();

  /// Portal origin for browser login / signup.
  ///
  /// Pass `--dart-define=FORJA_WEB_URL=https://…` in release builds.
  /// Defaults to the local Vite port so `flutter run` + `pnpm dev` works.
  static const String webUrl = String.fromEnvironment(
    'FORJA_WEB_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static Uri signupUri() => Uri.parse('$webUrl/signup');

  /// Starts a loopback listener, opens `/login?desktop_callback=…`, and
  /// resolves when the browser posts tokens back (or [timeout] / cancel).
  static Future<DesktopBrowserAuthResult> signIn({
    Duration timeout = const Duration(minutes: 5),
    Future<void> Function(Uri loginUrl)? launchBrowser,
  }) async {
    final state = _randomState();
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final callback = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: server.port,
        path: '/callback',
      );
      final loginUrl = Uri.parse('$webUrl/login').replace(
        queryParameters: {
          'desktop_callback': callback.toString(),
          'desktop_state': state,
        },
      );

      final completer = Completer<DesktopBrowserAuthResult>();
      late final StreamSubscription<HttpRequest> sub;
      Timer? timer;

      void finish(DesktopBrowserAuthResult result) {
        if (completer.isCompleted) return;
        completer.complete(result);
      }

      timer = Timer(timeout, () {
        finish(
          const DesktopBrowserAuthResult.failure(
            'Web login timed out. Try again, or sign in with email here.',
          ),
        );
      });

      sub = server.listen((request) async {
        try {
          if (request.method == 'GET' && request.uri.path == '/callback') {
            final params = request.uri.queryParameters;
            final returnedState = params['state'];
            final access = params['access_token'];
            final refresh = params['refresh_token'];
            final error = params['error'];

            if (error != null && error.isNotEmpty) {
              await _writeHtml(
                request,
                title: 'Sign-in cancelled',
                body: 'You can close this tab and return to Forja.',
                ok: false,
              );
              finish(DesktopBrowserAuthResult.failure(error));
              return;
            }

            if (returnedState != state ||
                access == null ||
                access.isEmpty ||
                refresh == null ||
                refresh.isEmpty) {
              await _writeHtml(
                request,
                title: 'Sign-in failed',
                body:
                    'Invalid or incomplete response. Close this tab and retry in Forja.',
                ok: false,
              );
              finish(
                const DesktopBrowserAuthResult.failure(
                  'Web login failed. Close the browser tab and try again.',
                ),
              );
              return;
            }

            await _writeHtml(
              request,
              title: 'Signed in',
              body: 'You can close this tab and return to Forja.',
              ok: true,
            );
            finish(
              DesktopBrowserAuthResult.success(
                accessToken: access,
                refreshToken: refresh,
              ),
            );
            return;
          }

          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        } catch (e, st) {
          debugPrint('[DesktopBrowserAuth] request error: $e\n$st');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });

      final launch = launchBrowser ?? _defaultLaunch;
      await launch(loginUrl);

      try {
        return await completer.future;
      } finally {
        timer.cancel();
        await sub.cancel();
      }
    } catch (e, st) {
      debugPrint('[DesktopBrowserAuth] failed: $e\n$st');
      return DesktopBrowserAuthResult.failure(
        'Could not open web login. Check your connection and try again.',
      );
    } finally {
      await server?.close(force: true);
    }
  }

  static Future<void> _defaultLaunch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw StateError('launchUrl returned false for $uri');
    }
  }

  static String _randomState() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<void> _writeHtml(
    HttpRequest request, {
    required String title,
    required String body,
    required bool ok,
  }) async {
    final accent = ok ? '#1CE783' : '#FF6B6B';
    final html =
        '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>$title — Forja</title>
  <style>
    :root { color-scheme: dark; }
    body {
      margin: 0; min-height: 100vh; display: grid; place-items: center;
      font-family: "Plus Jakarta Sans", system-ui, sans-serif;
      background: radial-gradient(ellipse 70% 55% at 20% 30%, rgba(28,231,131,.16), transparent 55%),
                  radial-gradient(ellipse 50% 45% at 85% 75%, rgba(255,90,40,.1), transparent 50%),
                  #141414;
      color: #E5E7EB;
    }
    main { text-align: center; padding: 2rem; max-width: 28rem; }
    h1 { font-size: 1.75rem; font-weight: 700; margin: 0 0 .75rem; letter-spacing: -.02em; }
    p { margin: 0; color: #9CA3AF; line-height: 1.5; }
    .dot { width: 10px; height: 10px; border-radius: 50%; background: $accent;
           margin: 0 auto 1.25rem; box-shadow: 0 0 24px $accent; }
  </style>
</head>
<body>
  <main>
    <div class="dot" aria-hidden="true"></div>
    <h1>$title</h1>
    <p>$body</p>
  </main>
</body>
</html>
''';
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.write(html);
    await response.close();
  }
}

class DesktopBrowserAuthResult {
  const DesktopBrowserAuthResult._({
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  const DesktopBrowserAuthResult.success({
    required String accessToken,
    required String refreshToken,
  }) : this._(accessToken: accessToken, refreshToken: refreshToken);

  const DesktopBrowserAuthResult.failure(String error) : this._(error: error);

  final String? accessToken;
  final String? refreshToken;
  final String? error;

  bool get isSuccess =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;
}
