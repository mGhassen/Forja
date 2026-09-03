import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_matches_sport_filter.dart';

void main() {
  group('normalizeLiveSportId', () {
    test('aliases PPV 24/7 Streams and sport buckets', () {
      expect(normalizeLiveSportId('24/7 Streams'), '24-7');
      expect(normalizeLiveSportId('24-7'), '24-7');
      expect(normalizeLiveSportId('Soccer'), 'football');
      expect(normalizeLiveSportId('american-football'), 'american-football');
      expect(normalizeLiveSportId('NFL'), 'american-football');
      expect(normalizeLiveSportId('NCAA Football'), 'american-football');
    });
  });

  group('liveSportDisplayName', () {
    test('renders 24/7 chip label', () {
      expect(liveSportDisplayName('24-7', '24-7'), '24/7');
      expect(liveSportDisplayName('24/7 Streams', '24-7'), '24/7');
    });
  });

  group('includeLiveMatchInSportFilter', () {
    test('Streamed always-on with sport slug only shows on 24/7 chip', () {
      // Willow Cricket / Tennis Channel / Rally TV - date 0, category = sport.
      expect(
        includeLiveMatchInSportFilter(
          category: 'cricket',
          isAlwaysOn: true,
          sportFilter: '24-7',
        ),
        isTrue,
      );
      expect(
        includeLiveMatchInSportFilter(
          category: 'cricket',
          isAlwaysOn: true,
          sportFilter: 'all',
        ),
        isFalse,
      );
      expect(
        includeLiveMatchInSportFilter(
          category: 'cricket',
          isAlwaysOn: true,
          sportFilter: 'cricket',
        ),
        isFalse,
      );
    });

    test('PPV 24/7 Streams category only shows on 24/7 chip', () {
      expect(
        includeLiveMatchInSportFilter(
          category: '24/7 Streams',
          isAlwaysOn: false,
          sportFilter: '24-7',
        ),
        isTrue,
      );
      expect(
        includeLiveMatchInSportFilter(
          category: '24/7 Streams',
          isAlwaysOn: false,
          sportFilter: 'all',
        ),
        isFalse,
      );
    });

    test('scheduled sport match stays on its sport chip and All', () {
      expect(
        includeLiveMatchInSportFilter(
          category: 'cricket',
          isAlwaysOn: false,
          sportFilter: 'cricket',
        ),
        isTrue,
      );
      expect(
        includeLiveMatchInSportFilter(
          category: 'cricket',
          isAlwaysOn: false,
          sportFilter: 'all',
        ),
        isTrue,
      );
      expect(
        includeLiveMatchInSportFilter(
          category: 'cricket',
          isAlwaysOn: false,
          sportFilter: '24-7',
        ),
        isFalse,
      );
    });
  });

  group('iframeCatalogStreamIsAlwaysOn', () {
    test('honors always_live even with expired start/end', () {
      expect(
        iframeCatalogStreamIsAlwaysOn(
          alwaysLive: true,
          categoryName: '24/7 Streams',
          startsAt: 1737176400,
          endsAt: 1740772800,
          hasIframe: true,
        ),
        isTrue,
      );
    });

    test('honors 24/7 category without always_live flag', () {
      expect(
        iframeCatalogStreamIsAlwaysOn(
          alwaysLive: false,
          categoryName: '24/7 Streams',
          startsAt: 1737176400,
          endsAt: 1740772800,
          hasIframe: true,
        ),
        isTrue,
      );
    });

    test('zero start/end with iframe is always-on', () {
      expect(
        iframeCatalogStreamIsAlwaysOn(
          alwaysLive: false,
          categoryName: 'Football',
          startsAt: 0,
          endsAt: 0,
          hasIframe: true,
        ),
        isTrue,
      );
    });

    test('scheduled non-24/7 match is not always-on', () {
      expect(
        iframeCatalogStreamIsAlwaysOn(
          alwaysLive: false,
          categoryName: 'Football',
          startsAt: 1737176400,
          endsAt: 1740772800,
          hasIframe: true,
        ),
        isFalse,
      );
    });
  });

  group('parseIframeCatalogAlwaysLive', () {
    test('accepts 1, true, and string forms', () {
      expect(parseIframeCatalogAlwaysLive(1), isTrue);
      expect(parseIframeCatalogAlwaysLive(true), isTrue);
      expect(parseIframeCatalogAlwaysLive('true'), isTrue);
      expect(parseIframeCatalogAlwaysLive(0), isFalse);
      expect(parseIframeCatalogAlwaysLive(null), isFalse);
    });
  });

  group('parseLiveViewerCount', () {
    test('parses numeric and string viewer counts from PPV API', () {
      expect(parseLiveViewerCount(99), 99);
      expect(parseLiveViewerCount('99'), 99);
      expect(parseLiveViewerCount(''), 0);
      expect(parseLiveViewerCount(null), 0);
    });
  });

  group('iframeCatalogStreamIsLive', () {
    const start = 1_000_000;
    const end = 1_010_000;

    test('true inside scheduled window', () {
      expect(
        iframeCatalogStreamIsLive(
          isAlwaysOn: false,
          status: '',
          startsAt: start,
          endsAt: end,
          viewers: 0,
          nowSecs: start + 5_000,
        ),
        isTrue,
      );
    });

    test('true with viewers after start within grace past ends_at', () {
      expect(
        iframeCatalogStreamIsLive(
          isAlwaysOn: false,
          status: '',
          startsAt: start,
          endsAt: end,
          viewers: 95,
          nowSecs: end + 60,
        ),
        isTrue,
      );
    });

    test('true with viewers shortly before start (clock skew / early doors)', () {
      expect(
        iframeCatalogStreamIsLive(
          isAlwaysOn: false,
          status: '',
          startsAt: start,
          endsAt: end,
          viewers: 50,
          nowSecs: start - 10,
        ),
        isTrue,
      );
    });

    test('true with viewers far before start (lobby / wrong device clock)', () {
      expect(
        iframeCatalogStreamIsLive(
          isAlwaysOn: false,
          status: '',
          startsAt: start,
          endsAt: end,
          viewers: 50,
          nowSecs: start - const Duration(hours: 7).inSeconds,
        ),
        isTrue,
      );
    });

    test('false with viewers long after ends_at grace', () {
      expect(
        iframeCatalogStreamIsLive(
          isAlwaysOn: false,
          status: '',
          startsAt: start,
          endsAt: end,
          viewers: 50,
          nowSecs: end + const Duration(hours: 4).inSeconds,
        ),
        isFalse,
      );
    });
  });
}
