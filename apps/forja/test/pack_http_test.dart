import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/pack_http.dart';

void main() {
  tearDown(() {
    PackHttp.debugClient = null;
    PackHttp.debugResolve = null;
    PackHttp.debugResetDnsCache();
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

    test('manifest gone local path', () {
      final msg = PackHttp.humanizeError(
        ManifestGoneException('/tmp/forja-packs/live/manifest.json'),
      );
      expect(msg, contains('Manifest not found'));
      expect(msg, contains('/tmp/forja-packs/live/manifest.json'));
    });
  });

  group('parseLiteralIp', () {
    test('accepts IPv4 and IPv6', () {
      expect(PackHttp.parseLiteralIp('1.1.1.1')?.address, '1.1.1.1');
      expect(PackHttp.parseLiteralIp('::1'), isNotNull);
    });

    test('rejects hostnames', () {
      expect(PackHttp.parseLiteralIp('raw.githubusercontent.com'), isNull);
      expect(PackHttp.parseLiteralIp('1.1.1.1.dns'), isNull);
    });
  });

  group('resolveHost literals', () {
    test('IP literal returns without DNS', () async {
      final addrs = await PackHttp.resolveHost('1.1.1.1');
      expect(addrs, hasLength(1));
      expect(addrs.single.address, '1.1.1.1');
      expect(addrs.single.type, InternetAddressType.IPv4);
    });
  });

  group('resolveHost race', () {
    test('DoH answer does not wait for a hung system lookup', () async {
      final hung = Completer<List<InternetAddress>>();
      var dohCalls = 0;
      PackHttp.debugSystemLookup = (_) => hung.future;
      PackHttp.debugDoh = (_) async {
        dohCalls++;
        return [InternetAddress('9.9.9.9')];
      };
      final sw = Stopwatch()..start();
      final addrs = await PackHttp.resolveHost('example.com');
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
      expect(addrs.single.address, '9.9.9.9');
      final again = await PackHttp.resolveHost('example.com');
      expect(again.single.address, '9.9.9.9');
      expect(dohCalls, 1);
    });

    test('in-flight lookups share one probe', () async {
      var dohCalls = 0;
      final gate = Completer<void>();
      PackHttp.debugSystemLookup = (_) async => const [];
      PackHttp.debugDoh = (_) async {
        dohCalls++;
        await gate.future;
        return [InternetAddress('1.2.3.4')];
      };
      final pending = Future.wait([
        PackHttp.resolveHost('joined.example'),
        PackHttp.resolveHost('joined.example'),
      ]);
      gate.complete();
      final both = await pending;
      expect(dohCalls, 1);
      expect(both[0].single.address, '1.2.3.4');
      expect(both[1].single.address, '1.2.3.4');
    });

    test('system addresses beat a slower DoH answer', () async {
      final dohHung = Completer<List<InternetAddress>>();
      PackHttp.debugSystemLookup = (_) async => [InternetAddress('10.1.1.1')];
      PackHttp.debugDoh = (_) => dohHung.future;
      final addrs = await PackHttp.resolveHost('split.example');
      expect(addrs.single.address, '10.1.1.1');
    });

    test('empty DoH still uses system DNS for a LAN name', () async {
      PackHttp.debugDoh = (_) async => const [];
      PackHttp.debugSystemLookup = (_) async => [InternetAddress('10.0.0.8')];
      final addrs = await PackHttp.resolveHost('portal.lan');
      expect(addrs.single.address, '10.0.0.8');
    });

    test('a system DNS timeout skips the next system probe', () async {
      final systemHosts = <String>[];
      PackHttp.debugSystemLookup = (host) async {
        systemHosts.add(host);
        throw TimeoutException('system DNS timed out');
      };
      PackHttp.debugDoh = (_) async => [InternetAddress('8.8.8.8')];
      await PackHttp.resolveHost('first.example');
      await PackHttp.resolveHost('second.example');
      expect(systemHosts, ['first.example']);
    });
  });

  group('systemDnsTimeout', () {
    test('is short enough that DoH can still run under defaultTimeout', () {
      expect(PackHttp.systemDnsTimeout.inSeconds, lessThanOrEqualTo(8));
      expect(
        PackHttp.systemDnsTimeout.inMilliseconds,
        lessThan(PackHttp.defaultTimeout.inMilliseconds),
      );
    });
  });
}
