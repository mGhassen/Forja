import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/registry/pack_http.dart';

void main() {
  tearDown(() {
    PackHttp.debugClient = null;
    PackHttp.debugResolve = null;
  });

  group('parseDohAnswers', () {
    test('reads A records', () {
      const body = '''
{"Status":0,"Answer":[
  {"name":"example.com.","type":1,"TTL":60,"data":"93.184.216.34"},
  {"name":"example.com.","type":5,"TTL":60,"data":"example.net."}
]}''';
      final addrs = PackHttp.parseDohAnswers(body, type: 'A');
      expect(addrs, hasLength(1));
      expect(addrs.single.address, '93.184.216.34');
      expect(addrs.single.type, InternetAddressType.IPv4);
    });

    test('reads AAAA records', () {
      const body = '''
{"Status":0,"Answer":[
  {"name":"example.com.","type":28,"TTL":60,"data":"2606:2800:220:1:248:1893:25c8:1946"}
]}''';
      final addrs = PackHttp.parseDohAnswers(body, type: 'AAAA');
      expect(addrs, hasLength(1));
      expect(addrs.single.type, InternetAddressType.IPv6);
    });

    test('empty on junk', () {
      expect(PackHttp.parseDohAnswers('nope', type: 'A'), isEmpty);
      expect(PackHttp.parseDohAnswers('{}', type: 'A'), isEmpty);
    });
  });

  group('humanizeError', () {
    test('dns failed host lookup', () {
      final msg = PackHttp.humanizeError(
        SocketException(
          'Failed host lookup: raw.githubusercontent.com',
          osError: const OSError('No address associated with hostname', 7),
        ),
        'https://raw.githubusercontent.com/mGhassen/forja-packs/main/hubs/home/manifest.json',
      );
      expect(msg, contains('Cannot resolve raw.githubusercontent.com'));
      expect(msg, contains('DNS'));
      expect(msg, contains('local path'));
    });

    test('timeout', () {
      final msg = PackHttp.humanizeError(
        TimeoutException('plugin fetch'),
        'https://raw.githubusercontent.com/x/y/main/manifest.json',
      );
      expect(msg, contains('timed out'));
      expect(msg, contains('raw.githubusercontent.com'));
    });
  });
}
