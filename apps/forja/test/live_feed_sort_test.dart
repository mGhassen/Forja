import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_feed_aggregate.dart';

void main() {
  group('sortLiveFeedRowsLiveFirst', () {
    test('airing before upcoming, then viewers, then kickoff', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final upcomingSoon = now + const Duration(hours: 1).inMilliseconds;
      final upcomingLater = now + const Duration(hours: 3).inMilliseconds;
      final rows = [
        {
          'id': 'up-late',
          'title': 'Later',
          'date': upcomingLater,
          'airing': false,
          'viewers': 900,
        },
        {
          'id': 'live-low',
          'title': 'Live A',
          'date': now - const Duration(minutes: 10).inMilliseconds,
          'airing': true,
          'viewers': 10,
        },
        {
          'id': 'up-soon',
          'title': 'Soon',
          'date': upcomingSoon,
          'airing': false,
          'viewers': 0,
        },
        {
          'id': 'live-high',
          'title': 'Live B',
          'date': now - const Duration(minutes: 5).inMilliseconds,
          'airing': true,
          'viewers': 500,
        },
      ];

      final sorted = sortLiveFeedRowsLiveFirst(rows);
      expect(
        [for (final r in sorted) r['id']],
        ['live-high', 'live-low', 'up-late', 'up-soon'],
      );
    });
  });
}
