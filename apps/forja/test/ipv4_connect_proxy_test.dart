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

  test('CONNECT proxy dials IPv4 and tunnels bytes', () async {
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
}
