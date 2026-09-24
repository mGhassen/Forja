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

  group('looksLikeMediaContainerBytes', () {
    test('accepts Matroska EBML and ISO BMFF magics', () {
      expect(
        looksLikeMediaContainerBytes([0x1a, 0x45, 0xdf, 0xa3, 0x01, 0x02]),
        isTrue,
      );
      expect(
        looksLikeMediaContainerBytes([
          0x00,
          0x00,
          0x00,
          0x18,
          0x66,
          0x74,
          0x79,
          0x70,
          0x69,
          0x73,
          0x6f,
          0x6d,
        ]),
        isTrue,
      );
    });

    test('rejects leading zeros / SegmentInfo-only (corrupt resume)', () {
      expect(looksLikeMediaContainerBytes([0, 0, 0, 0, 0, 0, 0, 0]), isFalse);
      // Matroska SegmentInfo without EBML is not playable.
      expect(
        looksLikeMediaContainerBytes([0x15, 0x49, 0xa9, 0x66, 0x40, 0x9e]),
        isFalse,
      );
    });
  });

  group('content disposition / range helpers', () {
    test('parses filename and Content-Range', () {
      expect(
        extensionFromContentDisposition(
          'attachment; filename="The.Love.Hypothesis.mkv"',
        ),
        '.mkv',
      );
      expect(extensionFromContentType('video/matroska'), '.mkv');
      expect(
        parseContentRangeStart('bytes 4151-1134420390/1134420391'),
        4151,
      );
      expect(
        parseContentRangeTotal('bytes 4151-1134420390/1134420391'),
        1134420391,
      );
    });
  });
}
