import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/platform/ipv4_connect_proxy.dart';

void main() {
  test('NAT64 AAAA plus IPv4 needs an IPv4 dial', () {
    expect(
      hostAddrsNeedIpv4Dial([
        InternetAddress('52.84.45.6'),
        InternetAddress('64:ff9b::3454:2d06'),
      ]),
      isTrue,
    );
  });

  test('real IPv6 is left alone', () {
    expect(
      hostAddrsNeedIpv4Dial([
        InternetAddress('1.1.1.1'),
        InternetAddress('2606:4700:4700::1111'),
      ]),
      isFalse,
    );
  });

  test('IPv4-only DNS does not need the proxy', () {
    expect(
      hostAddrsNeedIpv4Dial([InternetAddress('52.84.45.6')]),
      isFalse,
    );
  });

  test('connectFirstAddress skips a refused address', () async {
    final origin = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final socket = await connectFirstAddress(
      [
        InternetAddress('127.0.0.2'),
        InternetAddress.loopbackIPv4,
      ],
      origin.port,
    );
    final incoming = origin.first.timeout(const Duration(seconds: 3));
    socket.add('ping'.codeUnits);
    final got = await incoming;
    expect(got.remoteAddress.address, InternetAddress.loopbackIPv4.address);
    socket.destroy();
    got.destroy();
    await origin.close();
  });

  test('CONNECT proxy dials and tunnels bytes', () async {
    final origin = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = await Ipv4ConnectProxy.instance.endpoint();
    final proxy = Uri.parse(endpoint);
    final client = await Socket.connect(proxy.host, proxy.port);
    client.add(
      'CONNECT 127.0.0.1:${origin.port} HTTP/1.1\r\nHost: 127.0.0.1:${origin.port}\r\n\r\n'
          .codeUnits,
    );
    final incoming = await origin.first.timeout(const Duration(seconds: 3));
    incoming.add('hello-from-origin'.codeUnits);
    final got = String.fromCharCodes(
      await client.fold<List<int>>(<int>[], (a, b) {
        a.addAll(b);
        if (String.fromCharCodes(a).contains('hello-from-origin')) {
          client.destroy();
        }
        return a;
      }).timeout(const Duration(seconds: 3)),
    );
    expect(got, contains('200'));
    expect(got, contains('hello-from-origin'));
    incoming.destroy();
    await origin.close();
  });

  test('HTTP proxy rewrites an absolute GET and forwards the body', () async {
    final origin = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(origin.close);
    final endpoint = await Ipv4ConnectProxy.instance.endpoint();
    final proxy = Uri.parse(endpoint);
    final client = await Socket.connect(proxy.host, proxy.port);
    addTearDown(client.destroy);
    client.add(
      'GET http://127.0.0.1:${origin.port}/seg.ts?n=1 HTTP/1.1\r\n'
              'Host: 127.0.0.1:${origin.port}\r\n'
              'Proxy-Connection: keep-alive\r\n'
              '\r\n'
          .codeUnits,
    );
    final incoming = await origin.first.timeout(const Duration(seconds: 3));
    addTearDown(incoming.destroy);
    final req = String.fromCharCodes(
      await incoming.fold<List<int>>(<int>[], (a, b) {
        a.addAll(b);
        if (String.fromCharCodes(a).contains('\r\n\r\n')) incoming.destroy();
        return a;
      }).timeout(const Duration(seconds: 3)),
    );
    expect(req, startsWith('GET /seg.ts?n=1 HTTP/1.1\r\n'));
    expect(req, contains('Host: 127.0.0.1:${origin.port}'));
    expect(req.toLowerCase(), isNot(contains('proxy-connection')));
  });

  test('system DNS failure does not use the proxy', () async {
    debugResetPlaybackProxy();
    debugPlaybackSystemLookup = (_) async {
      throw const SocketException('no address');
    };
    addTearDown(debugResetPlaybackProxy);
    expect(
      await playbackHttpProxyFor('https://cdn.example/a.m3u8'),
      isNull,
    );
  });

  test('healthy IPv4 DNS does not use the proxy', () async {
    debugResetPlaybackProxy();
    debugPlaybackSystemLookup = (_) async => [InternetAddress('52.84.45.6')];
    addTearDown(debugResetPlaybackProxy);
    expect(
      await playbackHttpProxyFor('https://cdn.example/a.m3u8'),
      isNull,
    );
    expect(
      await playbackHttpProxyFor('http://cdn.example/live.ts'),
      isNull,
    );
  });

  test('NAT64 https and http both use the proxy', () async {
    debugResetPlaybackProxy();
    debugPlaybackSystemLookup = (_) async => [
      InternetAddress('52.84.45.6'),
      InternetAddress('64:ff9b::3454:2d06'),
    ];
    addTearDown(debugResetPlaybackProxy);
    expect(
      await playbackHttpProxyFor('https://cdn.example/a.m3u8'),
      startsWith('http://127.0.0.1:'),
    );
    expect(
      await playbackHttpProxyFor('http://cdn.example/live.ts'),
      startsWith('http://127.0.0.1:'),
    );
  });

  test('absolute HTTP rewrite drops the proxy request line', () {
    final parsed = parsePlaybackProxyHead(
      'GET http://cdn.example/a/b.ts?x=1 HTTP/1.1\r\n'
      'Host: cdn.example\r\n'
      'Range: bytes=0-\r\n',
    );
    expect(parsed, isNotNull);
    expect(parsed!.tunnel, isFalse);
    expect(parsed.host, 'cdn.example');
    expect(parsed.port, 80);
    final head = utf8.decode(parsed.upstreamHead);
    expect(head, startsWith('GET /a/b.ts?x=1 HTTP/1.1\r\n'));
    expect(head, contains('Range: bytes=0-\r\n'));
    expect(head, contains('Connection: close\r\n'));
  });
}
