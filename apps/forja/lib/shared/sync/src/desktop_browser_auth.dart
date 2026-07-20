import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

/// Opens the Forja web portal login and captures the session via a localhost
/// callback (desktop OAuth-style). The portal `fetch()`es the loopback URL so
/// the browser stays on one tab — it must not navigate to 127.0.0.1.
class DesktopBrowserAuth {
  DesktopBrowserAuth._();

  /// Portal origin for browser login / signup.
  ///
  /// Pass `--dart-define=FORJA_WEB_URL=https://…` (release: GitHub secret).
  /// Local `.env` should set `FORJA_WEB_URL=http://127.0.0.1:3000` (or the
  /// deployed https origin) and load via `--dart-define-from-file`.
  static const String webUrl = String.fromEnvironment(
    'FORJA_WEB_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// How long to keep `/focus` alive after a successful handoff so the portal
  /// can bring Forja forward when the user closes the tab.
  @visibleForTesting
  static Duration focusRetainDuration = const Duration(seconds: 45);

  /// Test hook — skips `window_manager` when set.
  @visibleForTesting
  static Future<void> Function()? bringToFrontOverride;

  static Uri signupUri() => Uri.parse('$webUrl/signup');

  /// Starts a loopback listener, opens `/login?desktop_callback=…`, and
  /// resolves when the browser posts tokens back (or [timeout] / [cancel]).
  ///
  /// Complete [cancel] to abort early (closes the loopback server and unlocks
  /// the UI). Prefer this over leaving the user stuck until [timeout].
  ///
  /// When [onTokens] is set, it runs **before** the portal gets `ok: true`, so
  /// the browser only closes after the session is actually applied. Tokens are
  /// still applied even if [cancel] already completed the wait (dispose /
  /// accidental cancel race).
  static Future<DesktopBrowserAuthResult> signIn({
    Duration timeout = const Duration(minutes: 5),
    Future<void> Function(Uri loginUrl)? launchBrowser,
    Future<void>? cancel,
    Future<void> Function(String accessToken, String refreshToken)? onTokens,
  }) async {
    final state = _randomState();
    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;
    var retainForFocus = false;
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
          // Helps the portal pick the handoff UI before auth hydrates.
          'desktop_client': 'forja',
        },
      );

      final completer = Completer<DesktopBrowserAuthResult>();
      final focusDone = Completer<void>();
      Timer? timer;
      var applyingTokens = false;

      void finish(DesktopBrowserAuthResult result) {
        if (completer.isCompleted) return;
        completer.complete(result);
      }

      timer = Timer(timeout, () {
        if (applyingTokens) return;
        finish(
          const DesktopBrowserAuthResult.failure(
            'Web login timed out. Try again, or sign in with email here.',
          ),
        );
      });

      if (cancel != null) {
        unawaited(
          cancel.then((_) {
            // Do not abort while setSession is in flight — that was closing the
            // browser (ok:true) while the app had already given up.
            if (applyingTokens) return;
            finish(
              const DesktopBrowserAuthResult.failure('Web login cancelled.'),
            );
          }),
        );
      }

      sub = server.listen((request) async {
        try {
          debugPrint(
            '[DesktopBrowserAuth] ${request.method} ${request.uri.path}',
          );
          // Portal hands off via fetch() from https://… so Chrome sends a
          // Private Network Access preflight. Never navigate the browser here —
          // that used to open a second 127.0.0.1 tab.
          if (request.method == 'OPTIONS') {
            _applyCors(request.response);
            request.response.statusCode = HttpStatus.noContent;
            await request.response.close();
            return;
          }

          if (request.method == 'GET' && request.uri.path == '/focus') {
            final returnedState = request.uri.queryParameters['state'];
            if (returnedState == state) {
              await _bringAppToFront();
              await _writeCallbackResponse(
                request,
                title: 'Focused',
                body: 'Forja is in front.',
                ok: true,
              );
              if (!focusDone.isCompleted) focusDone.complete();
            } else {
              _applyCors(request.response);
              request.response.statusCode = HttpStatus.forbidden;
              await request.response.close();
            }
            return;
          }

          if (request.method == 'GET' && request.uri.path == '/callback') {
            final params = request.uri.queryParameters;
            final returnedState = params['state'];
            final access = params['access_token'];
            final refresh = params['refresh_token'];
            final error = params['error'];

            if (error != null && error.isNotEmpty) {
              await _writeCallbackResponse(
                request,
                title: 'Sign-in cancelled',
                body: 'You can close this tab and return to Forja.',
                ok: false,
              );
              finish(DesktopBrowserAuthResult.failure(error));
              return;
            }

            // Incomplete / wrong-state hits must not abort the wait — browsers,
            // extensions, or probes can GET the callback URL without tokens.
            if (returnedState != state ||
                access == null ||
                access.isEmpty ||
                refresh == null ||
                refresh.isEmpty) {
              debugPrint(
                '[DesktopBrowserAuth] ignoring incomplete callback '
                '(stateOk=${returnedState == state}, '
                'hasAccess=${access != null && access.isNotEmpty}, '
                'hasRefresh=${refresh != null && refresh.isNotEmpty})',
              );
              await _writeCallbackResponse(
                request,
                title: 'Sign-in incomplete',
                body:
                    'Forja is still waiting. Finish sign-in in this tab, then '
                    'tap Return to Forja if needed.',
                ok: false,
              );
              return;
            }

            applyingTokens = true;
            try {
              if (onTokens != null) {
                await onTokens(access, refresh);
              }
              await _writeCallbackResponse(
                request,
                title: 'Signed in',
                body: 'You can close this tab and return to Forja.',
                ok: true,
              );
              debugPrint('[DesktopBrowserAuth] session handoff ok');
              finish(
                DesktopBrowserAuthResult.success(
                  accessToken: access,
                  refreshToken: refresh,
                ),
              );
            } catch (e, st) {
              debugPrint('[DesktopBrowserAuth] apply tokens failed: $e\n$st');
              await _writeCallbackResponse(
                request,
                title: 'Sign-in failed',
                body:
                    'Forja could not apply the session. Keep this tab open and '
                    'tap Return to Forja, or try Web login again from the app.',
                ok: false,
              );
              finish(
                DesktopBrowserAuthResult.failure(
                  'Web login failed to apply the session. Try again.',
                ),
              );
            } finally {
              applyingTokens = false;
            }
            return;
          }

          _applyCors(request.response);
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        } catch (e, st) {
          debugPrint('[DesktopBrowserAuth] request error: $e\n$st');
          try {
            _applyCors(request.response);
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });

      final launch = launchBrowser ?? _defaultLaunch;
      await launch(loginUrl);

      try {
        final result = await completer.future;
        if (result.isSuccess) {
          retainForFocus = true;
        }
        return result;
      } finally {
        timer.cancel();
        if (retainForFocus && server != null && sub != null) {
          final retainedServer = server;
          final retainedSub = sub;
          server = null;
          sub = null;
          unawaited(
            _retainFocusListener(
              server: retainedServer,
              sub: retainedSub,
              focusDone: focusDone,
            ),
          );
        } else {
          await sub?.cancel();
          sub = null;
        }
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

  static Future<void> _retainFocusListener({
    required HttpServer server,
    required StreamSubscription<HttpRequest> sub,
    required Completer<void> focusDone,
  }) async {
    try {
      if (focusRetainDuration <= Duration.zero) {
        if (!focusDone.isCompleted) focusDone.complete();
      } else {
        await Future.any<void>([
          focusDone.future,
          Future<void>.delayed(focusRetainDuration),
        ]);
      }
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  static Future<void> _bringAppToFront() async {
    final override = bringToFrontOverride;
    if (override != null) {
      await override();
      return;
    }
    if (kIsWeb) return;
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (e, st) {
      debugPrint('[DesktopBrowserAuth] bring to front failed: $e\n$st');
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

  /// CORS for portal `fetch()` handoff (incl. Chrome Private Network Access).
  static void _applyCors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      ..set(
        'Access-Control-Allow-Headers',
        'Content-Type, Access-Control-Request-Private-Network',
      )
      ..set('Access-Control-Allow-Private-Network', 'true');
  }

  static Future<void> _writeCallbackResponse(
    HttpRequest request, {
    required String title,
    required String body,
    required bool ok,
  }) async {
    final response = request.response;
    _applyCors(response);
    response.statusCode = HttpStatus.ok;
    // Prefer JSON for fetch(); keep a tiny HTML fallback if something navigates.
    final accept = request.headers.value(HttpHeaders.acceptHeader) ?? '';
    if (accept.contains('text/html') && !accept.contains('application/json')) {
      final accent = ok ? '#1CE783' : '#FF6B6B';
      response.headers.contentType = ContentType.html;
      response.write('''
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
      background: #141414; color: #E5E7EB;
    }
    main { text-align: center; padding: 2rem; max-width: 28rem; }
    h1 { font-size: 1.75rem; font-weight: 700; margin: 0 0 .75rem; }
    p { margin: 0; color: #9CA3AF; line-height: 1.5; }
    .dot { width: 10px; height: 10px; border-radius: 50%; background: $accent;
           margin: 0 auto 1.25rem; }
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
''');
    } else {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'ok': ok,
          'title': title,
          'body': body,
        }),
      );
    }
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
