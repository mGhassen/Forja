import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/protocol.dart';

void main() {
  group('hubMetaIsUpcoming', () {
    test('NOT_YET_RELEASED status is upcoming', () {
      const meta = CatalogMetaItem(
        id: 'test:1',
        type: 'drama',
        name: 'Soon',
        status: 'NOT_YET_RELEASED',
      );
      expect(hubMetaIsUpcoming(meta), isTrue);
    });

    test('future premiere with no episodes is upcoming', () {
      final meta = CatalogMetaItem(
        id: 'test:2',
        type: 'drama',
        name: 'Later',
        premiereDate: '2099-06-14',
      );
      expect(hubMetaIsUpcoming(meta, videos: const []), isTrue);
    });

    test('future premiere with episodes is not show-level upcoming', () {
      final meta = CatalogMetaItem(
        id: 'test:3',
        type: 'drama',
        name: 'Weekly',
        premiereDate: '2099-06-14',
      );
      const videos = [
        CatalogVideo(id: '1', title: 'Ep 1', episode: 1, airDate: '2099-06-14'),
      ];
      expect(hubMetaIsUpcoming(meta, videos: videos), isFalse);
    });
  });

  group('hubEpisodeMaps', () {
    test('passes air_date and aired to episode picker maps', () {
      const videos = [
        CatalogVideo(
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

  group('hubMetaPremiereDateLabel', () {
    test('formats ISO premiere for hero notice', () {
      const meta = CatalogMetaItem(
        id: 'test:4',
        type: 'drama',
        name: 'Premiere',
        premiereDate: '2026-06-14',
      );
      expect(hubMetaPremiereDateLabel(meta), 'Jun 14, 2026');
    });
  });
}
