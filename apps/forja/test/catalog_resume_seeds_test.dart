import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/store/continue_entries.dart';
import 'package:forja_foundation/protocol/protocol.dart';

void main() {
  test('home watch history entry carries tmdb id for Because seeds', () {
    final entry = catalogEntryFromHomeWatchHistory({
      'tmdbId': 550,
      'title': 'Fight Club',
      'posterPath': '/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg',
      'mediaType': 'movie',
      'position': 120000,
      'duration': 5000000,
      'updatedAt': 1,
      'uniqueId': '550',
    });
    expect(isHomeWatchHistoryEntry(entry), isTrue);
    final meta = entry['meta'];
    expect(meta, isA<Map>());
    final metaMap = Map<String, dynamic>.from(meta as Map);
    final parsed = MetaItem.fromJson(metaMap);
    final roundtrip = parsed.toJson();
    final ids = roundtrip['ids'];
    expect(ids, isA<Map>());
    expect((ids as Map)['tmdb']?.toString(), '550');
    expect(roundtrip['type']?.toString(), 'movie');
  });
}
