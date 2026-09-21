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

  test('lean Because seed keeps ids.tmdb for EngineJS tmdbBecause', () {
    final entry = catalogEntryFromHomeWatchHistory({
      'tmdbId': 1399,
      'title': 'Game of Thrones',
      'posterPath': '/u3bZgnGQ9T01s2Y89jsmp6gFJrH.jpg',
      'mediaType': 'tv',
      'season': 1,
      'episode': 1,
      'position': 60000,
      'duration': 3600000,
      'updatedAt': 2,
      'uniqueId': '1399',
    });
    final meta = Map<String, dynamic>.from(entry['meta'] as Map);
    final tmdb = (meta['ids'] as Map)['tmdb']?.toString();
    expect(tmdb, '1399');
    // Shape tmdbBecause reads: seed.meta.ids.tmdb + seed.meta.type.
    final lean = {
      'title': entry['title'],
      'meta': {
        'id': meta['id'],
        'type': meta['type'],
        'name': meta['name'],
        'ids': {'tmdb': tmdb},
      },
    };
    final seedMeta = lean['meta'] as Map;
    expect((seedMeta['ids'] as Map)['tmdb'], '1399');
    expect(seedMeta['type'], 'tv');
  });
}
