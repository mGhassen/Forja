import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_hooks.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
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

  group('catalogEntryFromHomeWatchHistory', () {
    test('maps WatchHistoryService row to catalog continue entry', () {
      final entry = catalogEntryFromHomeWatchHistory({
        'uniqueId': '42_S1_E3',
        'tmdbId': 42,
        'title': 'Show',
        'posterPath': '/p.jpg',
        'backdropPath': '/b.jpg',
        'position': 120000,
        'duration': 3600000,
        'season': 1,
        'episode': 3,
        'mediaType': 'tv',
        'updatedAt': 1000,
      });
      expect(isHomeWatchHistoryCatalogEntry(entry), isTrue);
      expect(entry['metaId'], '42_S1_E3');
      expect(entry['episodeNumber'], 3);
      expect(entry['positionMs'], 120000);
      expect(entry['cover'], contains('image.tmdb.org'));
    });
  });
}
