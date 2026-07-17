import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_matches_sport_filter.dart';

void main() {
  group('normalizeLiveSportId', () {
    test('aliases PPV 24/7 Streams and sport buckets', () {
      expect(normalizeLiveSportId('24/7 Streams'), '24-7');
      expect(normalizeLiveSportId('24-7'), '24-7');
      expect(normalizeLiveSportId('Soccer'), 'football');
      expect(normalizeLiveSportId('american-football'), 'american-football');
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
      // Willow Cricket / Tennis Channel / Rally TV — date 0, category = sport.
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

  group('ppvStreamIsAlwaysOn', () {
    test('honors always_live even with expired start/end', () {
      expect(
        ppvStreamIsAlwaysOn(
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
        ppvStreamIsAlwaysOn(
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
        ppvStreamIsAlwaysOn(
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
        ppvStreamIsAlwaysOn(
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

  group('parsePpvAlwaysLive', () {
    test('accepts 1, true, and string forms', () {
      expect(parsePpvAlwaysLive(1), isTrue);
      expect(parsePpvAlwaysLive(true), isTrue);
      expect(parsePpvAlwaysLive('true'), isTrue);
      expect(parsePpvAlwaysLive(0), isFalse);
      expect(parsePpvAlwaysLive(null), isFalse);
    });
  });

  group('parsePpvViewers', () {
    test('parses numeric and string viewer counts from PPV API', () {
      expect(parsePpvViewers(99), 99);
      expect(parsePpvViewers('99'), 99);
      expect(parsePpvViewers(''), 0);
      expect(parsePpvViewers(null), 0);
    });
  });

  group('ppvStreamIsLive', () {
    const start = 1_000_000;
    const end = 1_010_000;

    test('true inside scheduled window', () {
      expect(
        ppvStreamIsLive(
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
        ppvStreamIsLive(
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

    test('false before start even with viewers', () {
      expect(
        ppvStreamIsLive(
          isAlwaysOn: false,
          status: '',
          startsAt: start,
          endsAt: end,
          viewers: 50,
          nowSecs: start - 10,
        ),
        isFalse,
      );
    });
  });
}
