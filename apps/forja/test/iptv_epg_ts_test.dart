import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';

void main() {
  group('IptvClient.parseEpgTs', () {
    test('unix seconds become device-local', () {
      // 2023-11-14 22:13:20 UTC
      final d = IptvClient.parseEpgTs(1700000000);
      expect(d, isNotNull);
      expect(d!.isUtc, isFalse);
      expect(d.toUtc(), DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    test('unix millis become device-local', () {
      final d = IptvClient.parseEpgTs(1700000000000);
      expect(d, isNotNull);
      expect(d!.toUtc(), DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    test('Zulu string converts to local', () {
      final d = IptvClient.parseEpgTs('2026-04-25T19:00:00Z');
      expect(d, isNotNull);
      expect(d!.isUtc, isFalse);
      expect(d.toUtc(), DateTime.utc(2026, 4, 25, 19));
    });

    test('naive wall-clock stays local (no shift)', () {
      final d = IptvClient.parseEpgTs('2026-04-25 19:00:00');
      expect(d, isNotNull);
      expect(d!.isUtc, isFalse);
      expect(d.year, 2026);
      expect(d.month, 4);
      expect(d.day, 25);
      expect(d.hour, 19);
      expect(d.minute, 0);
    });

    test('rejects junk', () {
      expect(IptvClient.parseEpgTs(null), isNull);
      expect(IptvClient.parseEpgTs(''), isNull);
      expect(IptvClient.parseEpgTs('not-a-date'), isNull);
    });
  });
}
