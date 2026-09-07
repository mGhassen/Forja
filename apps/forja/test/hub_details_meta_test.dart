import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/blocks/details/kit_details_meta.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';

void main() {
  group('hubMetaIsUpcoming', () {
    test('NOT_YET_RELEASED status is upcoming', () {
      const meta = MetaItem(
        id: 'test:1',
        type: 'drama',
        name: 'Soon',
        status: 'NOT_YET_RELEASED',
      );
      expect(hubMetaIsUpcoming(meta), isTrue);
    });

    test('future premiere with no episodes is upcoming', () {
      final meta = MetaItem(
        id: 'test:2',
        type: 'drama',
        name: 'Later',
        premiereDate: '2099-06-14',
      );
      expect(hubMetaIsUpcoming(meta, videos: const []), isTrue);
    });

    test('all future episode stubs is show-level upcoming', () {
      final meta = MetaItem(
        id: 'test:3',
        type: 'drama',
        name: 'Weekly',
        premiereDate: '2099-06-14',
        releaseInfo: '2025',
      );
      const videos = [
        MetaVideo(
          id: '1',
          title: 'Ep 1',
          episode: 1,
          airDate: '2099-06-14',
          aired: false,
        ),
        MetaVideo(
          id: '2',
          title: 'Ep 2',
          episode: 2,
          airDate: '2099-06-21',
          aired: false,
        ),
      ];
      expect(hubMetaIsUpcoming(meta, videos: videos), isTrue);
    });

    test('mixed aired and future episodes is not show-level upcoming', () {
      const meta = MetaItem(
        id: 'test:4',
        type: 'drama',
        name: 'Airing',
      );
      const videos = [
        MetaVideo(
          id: '1',
          title: 'Ep 1',
          episode: 1,
          airDate: '2020-01-01',
          aired: true,
        ),
        MetaVideo(
          id: '2',
          title: 'Ep 2',
          episode: 2,
          airDate: '2099-06-14',
          aired: false,
        ),
      ];
      expect(hubMetaIsUpcoming(meta, videos: videos), isFalse);
    });
  });

  group('hubEpisodeMaps', () {
    test('passes air_date and aired to episode picker maps', () {
      const videos = [
        MetaVideo(
          id: 'v1',
          title: 'Pilot',
          episode: 1,
          airDate: '2099-01-15',
          aired: false,
        ),
      ];
      final maps = hubEpisodeMaps(videos);
      expect(maps, isNotNull);
      final ep = maps![1]!.single;
      expect(ep['air_date'], '2099-01-15');
      expect(ep['aired'], isFalse);
      expect(hubVideoNotAiredYet(videos.first), isTrue);
    });
  });

  group('hubMergeDetailsSeed', () {
    test('keeps seed poster when details poster empty', () {
      const seed = MetaItem(
        id: 'brstej:watch:abc',
        type: 'arabic',
        name: 'Show',
        poster: 'https://example.com/seed.jpg',
        description: 'from list',
      );
      const details = MetaItem(
        id: 'brstej:watch:abc',
        type: 'arabic',
        name: 'Show',
        videos: [
          MetaVideo(id: '1', title: 'Ep 1', episode: 1),
        ],
      );
      final merged = hubMergeDetailsSeed(details, seed);
      expect(merged.poster, 'https://example.com/seed.jpg');
      expect(merged.background, 'https://example.com/seed.jpg');
      expect(merged.description, 'from list');
      expect(merged.videos, hasLength(1));
    });

    test('prefers details artwork when present', () {
      const seed = MetaItem(
        id: 'brstej:watch:abc',
        type: 'arabic',
        name: 'Show',
        poster: 'https://example.com/seed.jpg',
      );
      const details = MetaItem(
        id: 'brstej:watch:abc',
        type: 'arabic',
        name: 'Show',
        poster: 'https://example.com/details.jpg',
        background: 'https://example.com/bg.jpg',
        description: 'synopsis',
      );
      final merged = hubMergeDetailsSeed(details, seed);
      expect(merged.poster, 'https://example.com/details.jpg');
      expect(merged.background, 'https://example.com/bg.jpg');
      expect(merged.description, 'synopsis');
    });
  });

  group('hubMetaPremiereDateLabel', () {
    test('formats ISO premiere for hero notice', () {
      const meta = MetaItem(
        id: 'test:5',
        type: 'drama',
        name: 'Premiere',
        premiereDate: '2026-06-14',
      );
      expect(hubMetaPremiereDateLabel(meta), 'Jun 14, 2026');
    });

    test('falls back to earliest episode air date', () {
      const meta = MetaItem(
        id: 'test:6',
        type: 'drama',
        name: 'Stubs',
        releaseInfo: '2025',
      );
      const videos = [
        MetaVideo(id: '2', title: 'Ep 2', episode: 2, airDate: '2099-06-21'),
        MetaVideo(id: '1', title: 'Ep 1', episode: 1, airDate: '2099-06-14'),
      ];
      expect(
        hubMetaPremiereDateLabel(meta, videos: videos),
        'Jun 14, 2099',
      );
    });
  });
}
