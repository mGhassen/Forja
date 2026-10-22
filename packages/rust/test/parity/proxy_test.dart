import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  tearDown(() {
    RustLib.instance.proxyStop();
  });

  test('proxy starts and exposes health endpoint', () async {
    final port = RustLib.instance.proxyStart(0);
    expect(port, greaterThan(0));
    expect(RustLib.instance.proxyPort(), port);

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = await res.transform(utf8.decoder).join();
      expect(body, 'ok');
    } finally {
      client.close(force: true);
    }
  });

  test('proxy registers token route', () {
    final port = RustLib.instance.proxyStart(0);
    expect(port, greaterThan(0));
    expect(
      RustLib.instance.proxyRegisterRoute(
        'abc',
        'https://example.com/stream.bin',
      ),
      isTrue,
    );
  });

  test('proxy creates ext session for DASH handoff', () async {
    final port = RustLib.instance.proxyStart(0);
    expect(port, greaterThan(0));

    final play = RustLib.instance.proxyCreateExtSession(
      'https://cdn.example/dash/abc/index_web.mpd',
      json.encode({
        'Cookie': 'CloudFront-Policy=x',
        'User-Agent': 'ForjaTest/1',
      }),
    );
    expect(play, contains('http://127.0.0.1:$port/ext/'));
    expect(play, endsWith('/index_web.mpd'));

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(play));
      final res = await req.close();
      // Upstream is fake — expect gateway/error, not 404 on the route itself.
      expect(res.statusCode, isNot(404));
    } finally {
      client.close(force: true);
    }
  });

  test('proxy token is non-empty after start and gates media routes', () async {
    final port = RustLib.instance.proxyStart(0);
    expect(port, greaterThan(0));
    final token = RustLib.instance.proxyToken();
    expect(token, isNotEmpty);
    expect(token, matches(RegExp(r'^[0-9a-f]+$')));
    // Stops after the proxy is down.
    expect(RustLib.instance.proxyPort(), port);

    final client = HttpClient();
    try {
      const target = 'https%3A%2F%2Fcdn.example%2Fa.m3u8';
      final noToken = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/hls-proxy?url=$target&headers=%7B%7D'),
      );
      expect((await noToken.close()).statusCode, 403);

      final withToken = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:$port/hls-proxy?url=$target&headers=%7B%7D'
          '&proxy_token=$token',
        ),
      );
      // Upstream is fake — anything but the 403 gate.
      expect((await withToken.close()).statusCode, isNot(403));

      final viaHeader = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/hls-proxy?url=$target&headers=%7B%7D'),
      );
      viaHeader.headers.set('x-forja-proxy-token', token);
      expect((await viaHeader.close()).statusCode, isNot(403));

      // Health stays open.
      final health = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      expect((await health.close()).statusCode, 200);
    } finally {
      client.close(force: true);
    }
  });

  test('proxy token rotates per start and clears on stop', () async {
    final first = RustLib.instance.proxyStart(0);
    expect(first, greaterThan(0));
    final a = RustLib.instance.proxyToken();
    RustLib.instance.proxyStop();
    expect(RustLib.instance.proxyToken(), isEmpty);
    final second = RustLib.instance.proxyStart(0);
    expect(second, greaterThan(0));
    final b = RustLib.instance.proxyToken();
    expect(b, isNotEmpty);
    expect(b, isNot(a));
  });

  test('proxy specialized routes are registered', () async {
    final port = RustLib.instance.proxyStart(0);
    expect(port, greaterThan(0));

    final client = HttpClient();
    try {
      final token = RustLib.instance.proxyToken();
      final t = 'proxy_token=$token';

      final subtitlecat = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/subtitlecat-translate?$t'),
      );
      expect((await subtitlecat.close()).statusCode, 400);

      final jellyfin = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/jellyfin-stream?$t'),
      );
      expect((await jellyfin.close()).statusCode, isNot(404));

      final comic = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/comic-proxy?$t'),
      );
      expect((await comic.close()).statusCode, 404);

      final toky = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/toky-proxy?url=http%3A%2F%2Fbad&$t'),
      );
      expect((await toky.close()).statusCode, isNot(404));

      // Without the token every media route is gated.
      final gated = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/toky-proxy?url=http%3A%2F%2Fbad'),
      );
      expect((await gated.close()).statusCode, 403);
    } finally {
      client.close(force: true);
    }
  });
}
