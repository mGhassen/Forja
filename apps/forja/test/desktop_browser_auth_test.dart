import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';

void main() {
  setUp(() {
    // Avoid pending timers from the post-handoff /focus retain window.
    DesktopBrowserAuth.focusRetainDuration = Duration.zero;
    DesktopBrowserAuth.bringToFrontOverride = () async {};
  });

  tearDown(() {
    DesktopBrowserAuth.bringToFrontOverride = null;
  });

  test('DesktopBrowserAuthResult success requires both tokens', () {
    const ok = DesktopBrowserAuthResult.success(
      accessToken: 'a',
      refreshToken: 'r',
    );
    expect(ok.isSuccess, isTrue);

    const bad = DesktopBrowserAuthResult.failure('nope');
    expect(bad.isSuccess, isFalse);
    expect(bad.error, 'nope');
  });

  test('signIn completes when browser posts tokens to loopback', () async {
    final future = DesktopBrowserAuth.signIn(
      timeout: const Duration(seconds: 8),
      launchBrowser: (loginUrl) async {
        expect(loginUrl.path, '/login');
        expect(loginUrl.queryParameters['desktop_callback'], isNotEmpty);
        expect(loginUrl.queryParameters['desktop_state'], isNotEmpty);

        final callback = Uri.parse(
          loginUrl.queryParameters['desktop_callback']!,
        );
        final state = loginUrl.queryParameters['desktop_state']!;
        final handoff = callback.replace(
          queryParameters: {
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'state': state,
          },
        );

        final client = HttpClient();
        try {
          final request = await client.getUrl(handoff);
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
      },
    );

    final result = await future;
    expect(result.isSuccess, isTrue);
    expect(result.accessToken, 'access-token');
    expect(result.refreshToken, 'refresh-token');
  });

  test('signIn finishes when cancel completes', () async {
    final cancel = Completer<void>();
    final future = DesktopBrowserAuth.signIn(
      timeout: const Duration(seconds: 8),
      cancel: cancel.future,
      launchBrowser: (_) async {
        cancel.complete();
      },
    );

    final result = await future;
    expect(result.isSuccess, isFalse);
    expect(result.error, 'Web login cancelled.');
  });

  test('signIn applies onTokens before returning ok to the browser', () async {
    var applied = false;
    String? body;
    final future = DesktopBrowserAuth.signIn(
      timeout: const Duration(seconds: 8),
      onTokens: (access, refresh) async {
        expect(access, 'access-token');
        expect(refresh, 'refresh-token');
        // Simulate slow setSession — response must wait.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        applied = true;
      },
      launchBrowser: (loginUrl) async {
        final callback = Uri.parse(
          loginUrl.queryParameters['desktop_callback']!,
        );
        final state = loginUrl.queryParameters['desktop_state']!;
        final handoff = callback.replace(
          queryParameters: {
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'state': state,
          },
        );
        final client = HttpClient();
        try {
          final request = await client.getUrl(handoff);
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          body = await response.transform(utf8.decoder).join();
        } finally {
          client.close(force: true);
        }
      },
    );

    final result = await future;
    expect(result.isSuccess, isTrue);
    expect(applied, isTrue);
    expect(body, contains('"ok":true'));
  });

  test('signIn keeps waiting after incomplete callback', () async {
    final future = DesktopBrowserAuth.signIn(
      timeout: const Duration(seconds: 8),
      launchBrowser: (loginUrl) async {
        final callback = Uri.parse(
          loginUrl.queryParameters['desktop_callback']!,
        );
        final state = loginUrl.queryParameters['desktop_state']!;
        final client = HttpClient();
        try {
          final bad = await client.getUrl(callback);
          final badResponse = await bad.close();
          expect(badResponse.statusCode, HttpStatus.ok);
          await badResponse.drain<void>();

          final handoff = callback.replace(
            queryParameters: {
              'access_token': 'access-token',
              'refresh_token': 'refresh-token',
              'state': state,
            },
          );
          final request = await client.getUrl(handoff);
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
      },
    );

    final result = await future;
    expect(result.isSuccess, isTrue);
    expect(result.accessToken, 'access-token');
  });

  test('signIn accepts CORS preflight then token fetch', () async {
    final future = DesktopBrowserAuth.signIn(
      timeout: const Duration(seconds: 8),
      launchBrowser: (loginUrl) async {
        final callback = Uri.parse(
          loginUrl.queryParameters['desktop_callback']!,
        );
        final state = loginUrl.queryParameters['desktop_state']!;
        final client = HttpClient();
        try {
          final preflight = await client.openUrl('OPTIONS', callback);
          preflight.headers.set(
            'Access-Control-Request-Private-Network',
            'true',
          );
          final preflightResponse = await preflight.close();
          expect(preflightResponse.statusCode, HttpStatus.noContent);
          expect(
            preflightResponse.headers.value(
              'access-control-allow-private-network',
            ),
            'true',
          );
          await preflightResponse.drain<void>();

          final handoff = callback.replace(
            queryParameters: {
              'access_token': 'access-token',
              'refresh_token': 'refresh-token',
              'state': state,
            },
          );
          final request = await client.getUrl(handoff);
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          expect(response.headers.value('access-control-allow-origin'), '*');
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
      },
    );

    final result = await future;
    expect(result.isSuccess, isTrue);
  });

  test('cancel during onTokens does not abort a successful handoff', () async {
    final cancel = Completer<void>();
    var applied = false;
    final future = DesktopBrowserAuth.signIn(
      timeout: const Duration(seconds: 8),
      cancel: cancel.future,
      onTokens: (access, refresh) async {
        cancel.complete();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        applied = true;
      },
      launchBrowser: (loginUrl) async {
        final callback = Uri.parse(
          loginUrl.queryParameters['desktop_callback']!,
        );
        final state = loginUrl.queryParameters['desktop_state']!;
        final handoff = callback.replace(
          queryParameters: {
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'state': state,
          },
        );
        final client = HttpClient();
        try {
          final request = await client.getUrl(handoff);
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          final response = await request.close();
          final body = await response.transform(utf8.decoder).join();
          expect(response.statusCode, HttpStatus.ok);
          expect(body, contains('"ok":true'));
        } finally {
          client.close(force: true);
        }
      },
    );

    final result = await future;
    expect(applied, isTrue);
    expect(result.isSuccess, isTrue);
  });
}
