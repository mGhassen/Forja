import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/list_follow_from_watched.dart';

void main() {
  group('ListFollowFromWatched.nextStatus', () {
    test('first mark → watching', () {
      expect(
        ListFollowFromWatched.nextStatus(
          current: null,
          watchedCount: 1,
          totalEpisodes: 10,
          episodeNowWatched: true,
        ),
        'watching',
      );
      expect(
        ListFollowFromWatched.nextStatus(
          current: 'plantowatch',
          watchedCount: 1,
          totalEpisodes: 10,
          episodeNowWatched: true,
        ),
        'watching',
      );
    });

    test('leave hold / watching alone mid-series', () {
      expect(
        ListFollowFromWatched.nextStatus(
          current: 'hold',
          watchedCount: 2,
          totalEpisodes: 10,
          episodeNowWatched: true,
        ),
        isNull,
      );
      expect(
        ListFollowFromWatched.nextStatus(
          current: 'watching',
          watchedCount: 2,
          totalEpisodes: 10,
          episodeNowWatched: true,
        ),
        isNull,
      );
    });

    test('all marked → completed', () {
      expect(
        ListFollowFromWatched.nextStatus(
          current: 'watching',
          watchedCount: 10,
          totalEpisodes: 10,
          episodeNowWatched: true,
        ),
        'completed',
      );
    });

    test('unmark from completed → watching', () {
      expect(
        ListFollowFromWatched.nextStatus(
          current: 'completed',
          watchedCount: 9,
          totalEpisodes: 10,
          episodeNowWatched: false,
        ),
        'watching',
      );
    });
  });
}
