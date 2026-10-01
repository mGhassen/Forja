import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja_foundation/protocol/protocol.dart';

void main() {
  group('metaDeclaredEpisodeCount', () {
    test('prefers MetaItem.episodes over facts / videos', () {
      final item = MetaItem(
        id: 'tmdb:tv:1',
        type: 'tv',
        name: 'Show',
        episodes: 24,
        facts: const {'episodeCount': 10},
        videos: List.generate(
          3,
          (i) => MetaVideo(
            id: 'e$i',
            title: 'E${i + 1}',
            episode: i + 1,
            season: 1,
          ),
        ),
      );
      expect(metaDeclaredEpisodeCount(item), 24);
    });

    test('uses facts.episodeCount when episodes unset', () {
      final item = MetaItem(
        id: 'tmdb:tv:2',
        type: 'tv',
        name: 'Show',
        facts: const {'episodeCount': 12},
        videos: const [
          MetaVideo(id: 'e1', title: 'E1', episode: 1, season: 1),
        ],
      );
      expect(metaDeclaredEpisodeCount(item), 12);
    });

    test('returns 0 when only videos are present (no invent)', () {
      final item = MetaItem(
        id: 'tmdb:tv:3',
        type: 'tv',
        name: 'Show',
        videos: const [
          MetaVideo(id: 'e1', title: 'E1', episode: 1, season: 1),
        ],
      );
      expect(metaDeclaredEpisodeCount(item), 0);
    });
  });
}
