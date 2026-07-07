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

  test('proxy specialized routes are registered', () async {
    final port = RustLib.instance.proxyStart(0);
    expect(port, greaterThan(0));

    final client = HttpClient();
    try {
      final subtitlecat = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/subtitlecat-translate'),
      );
      expect((await subtitlecat.close()).statusCode, 400);

      final jellyfin = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/jellyfin-stream'),
      );
      expect((await jellyfin.close()).statusCode, isNot(404));

      final comic = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/comic-proxy'),
      );
      expect((await comic.close()).statusCode, 404);

      final toky = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/toky-proxy?url=http%3A%2F%2Fbad'),
      );
      expect((await toky.close()).statusCode, isNot(404));
    } finally {
      client.close(force: true);
    }
  });
}
