import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/store/continue_entries.dart';

void main() {
  test('catalogEntryFromHomeWatchHistory accepts double season/episode', () {
    final entry = catalogEntryFromHomeWatchHistory({
      'uniqueId': '99_S1_E2',
      'tmdbId': '99',
      'title': 'Show',
      'posterPath': '/p.jpg',
      'backdropPath': '/b.jpg',
      'position': 120_000,
      'duration': 2_400_000,
      'season': 1.0,
      'episode': 2.0,
      'mediaType': 'tv',
      'updatedAt': 1,
    });
    expect(entry['episodeNumber'], 2);
    expect(entry['positionMs'], 120_000);
    expect(entry['durationMs'], 2_400_000);
    expect(isHomeWatchHistoryEntry(entry), isTrue);
  });
}
