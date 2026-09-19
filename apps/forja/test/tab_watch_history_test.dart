import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/play_hooks.dart';
import 'package:forja/shared/playback/play_session.dart';
import 'package:rust/rust.dart';

Movie _movie({required int id, String mediaType = 'movie'}) => Movie(
      id: id,
      title: 'T',
      posterPath: '/p.jpg',
      backdropPath: '',
      voteAverage: 0,
      releaseDate: '',
      mediaType: mediaType,
    );

void main() {
  group('hubMediaIsEpisodic', () {
    test('tv and any non-movie/tv pack type are episodic', () {
      expect(hubMediaIsEpisodic(_movie(id: 1, mediaType: 'tv')), isTrue);
      expect(hubMediaIsEpisodic(_movie(id: 1, mediaType: 'anime')), isTrue);
      expect(
        hubMediaIsEpisodic(_movie(id: 1, mediaType: 'asian_drama')),
        isTrue,
      );
      expect(hubMediaIsEpisodic(_movie(id: 1, mediaType: 'foo')), isTrue);
      expect(hubMediaIsEpisodic(_movie(id: 1, mediaType: 'movie')), isFalse);
    });
  });

  group('usesHomeWatchHistory', () {
    test('rejects hub media types and synthetic ids', () {
      expect(
        usesHomeWatchHistory(movie: _movie(id: -42, mediaType: 'anime')),
        isFalse,
      );
      expect(
        usesHomeWatchHistory(
          movie: _movie(id: 99, mediaType: 'asian_drama'),
        ),
        isFalse,
      );
      expect(usesHomeWatchHistory(movie: _movie(id: 99)), isTrue);
    });

    test('rejects when hub hooks are present', () {
      final movie = _movie(id: 99, mediaType: 'tv');
      expect(
        usesHomeWatchHistory(
          movie: movie,
          onSaveProgress: (_, _, {sourceId, streamUrl}) async {},
        ),
        isFalse,
      );
    });

    test('TMDB home via pack still writes home history with kit callback', () {
      final movie = _movie(id: 99, mediaType: 'tv');
      expect(
        usesHomeWatchHistory(
          movie: movie,
          episodes: const [],
          onSaveProgress: (_, _, {sourceId, streamUrl}) async {},
          playSession: const PlaySession(useHomeEpisodeWatched: true),
        ),
        isTrue,
      );
    });
  });

  group('isContinueWatchingRowEntry', () {
    test('lists short saves on long runtimes once past player gate', () {
      expect(isContinueWatchingRowEntry(15_000, 3_600_000), isTrue);
      expect(isInProgressResume(15_000, 3_600_000), isFalse);
    });

    test('still hides finished and unsaved rows', () {
      expect(isContinueWatchingRowEntry(0, 3_600_000), isFalse);
      expect(isContinueWatchingRowEntry(3_200_000, 3_600_000), isFalse);
      expect(isContinueWatchingRowEntry(5_000, 3_600_000), isFalse);
    });
  });
}
