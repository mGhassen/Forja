import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_guards.dart';

void main() {
  group('isDownloadAuthExpired', () {
    test('rejects expired expires= on the play URL', () {
      final now = DateTime.utc(2026, 9, 24, 18, 34);
      const url =
          'https://cdn.example/playlist/1?expires=1790274746&token=abc';
      expect(isDownloadAuthExpired(url, now: now), isTrue);
      expect(isDownloadableHttpUrl(url, now: now), isFalse);
    });

    test('rejects expired expires= on Referer while URL has none', () {
      final now = DateTime.utc(2026, 9, 24, 18, 34);
      const url = 'https://vidsrc.buzz/_stream?id=abc';
      final headers = {
        'Referer':
            'https://vixsrc.to/embed/1?token=x&expires=1790274746&lang=en',
        'Origin': 'https://vixsrc.to',
        'User-Agent': 'Mozilla/5.0',
      };
      expect(
        isDownloadAuthExpired(url, headers: headers, now: now),
        isTrue,
      );
      expect(
        isDownloadableHttpUrl(url, headers: headers, now: now),
        isFalse,
      );
      expect(
        offlineDownloadRejectReason(url, headers: headers, now: now),
        kOfflineDownloadExpiredMessage,
      );
    });

    test('accepts fresh Referer expires=', () {
      final now = DateTime.utc(2026, 9, 24, 18, 0);
      const url = 'https://vidsrc.buzz/_stream?id=abc';
      final headers = {
        'Referer':
            'https://vixsrc.to/embed/1?token=x&expires=2000000000&lang=en',
      };
      expect(
        isDownloadAuthExpired(url, headers: headers, now: now),
        isFalse,
      );
      expect(
        isDownloadableHttpUrl(url, headers: headers, now: now),
        isTrue,
      );
    });
  });
}
