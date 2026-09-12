import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/protocol.dart';

void main() {
  group('userFacingCatalogError', () {
    test('maps rate-limit code', () {
      expect(
        userFacingCatalogError(
          const MetaError(code: MetaErrorCode.rateLimit, message: 'ignored'),
        ),
        'Too many requests. Wait a moment, then retry.',
      );
    });

    test('upgrades anilist HTTP 429 upstream message', () {
      expect(
        userFacingCatalogError(
          const MetaError(
            code: MetaErrorCode.upstream,
            message: 'anilist HTTP 429',
          ),
        ),
        'Too many requests. Wait a moment, then retry.',
      );
      expect(
        effectiveCatalogErrorCode(
          const MetaError(
            code: MetaErrorCode.upstream,
            message: 'anilist HTTP 429',
          ),
        ),
        MetaErrorCode.rateLimit,
      );
    });

    test('never returns raw upstream text', () {
      final copy = userFacingCatalogError(
        const MetaError(
          code: MetaErrorCode.upstream,
          message: 'tmdb HTTP 503 for https://api.themoviedb.org',
        ),
      );
      expect(copy.contains('HTTP'), isFalse);
      expect(copy.contains('tmdb'), isFalse);
      expect(copy, 'Couldn’t reach the catalog. Try again.');
    });

    test('maps Cloudflare temporarily disabled', () {
      expect(
        userFacingCatalogError(
          const MetaError(
            code: MetaErrorCode.upstream,
            message: 'anilist temporarily disabled',
          ),
        ),
        'Server is down. Try again later.',
      );
    });

    test('null uses fallback', () {
      expect(
        userFacingCatalogError(null, fallback: 'Couldn’t load this hub.'),
        'Couldn’t load this hub.',
      );
    });
  });
}
