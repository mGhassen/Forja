import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/list_follow_from_watched.dart';
import 'package:rust/rust.dart';

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

  group('ListFollowFromWatched movie guards', () {
    test('markMovieWatchingOnPlay no-ops for tv', () async {
      final tv = Movie(
        id: 1,
        title: 'Show',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '',
        overview: '',
        genres: const [],
        runtime: 0,
        mediaType: 'tv',
      );
      await ListFollowFromWatched.markMovieWatchingOnPlay(tv);
    });

    test('markMovieCompletedIfFinished no-ops under threshold', () async {
      final movie = Movie(
        id: 2,
        title: 'Film',
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '',
        overview: '',
        genres: const [],
        runtime: 120,
        mediaType: 'movie',
      );
      await ListFollowFromWatched.markMovieCompletedIfFinished(
        movie,
        positionMs: 50_000,
        durationMs: 100_000,
      );
    });
  });
}
