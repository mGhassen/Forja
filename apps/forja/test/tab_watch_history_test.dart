import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_hooks.dart';
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
          onSaveProgress: (_, _) async {},
        ),
        isFalse,
      );
    });
  });

  group('isHomeTabWatchHistoryEntry', () {
    test('filters hub rows out of Home CW', () {
      expect(
        isHomeTabWatchHistoryEntry({'tmdbId': 1, 'mediaType': 'tv'}),
        isTrue,
      );
      expect(
        isHomeTabWatchHistoryEntry({'tmdbId': 1, 'mediaType': 'asian_drama'}),
        isFalse,
      );
      expect(
        isHomeTabWatchHistoryEntry({'tmdbId': -1, 'mediaType': 'tv'}),
        isFalse,
      );
    });
  });
}
