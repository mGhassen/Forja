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
}
