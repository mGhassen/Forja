import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/details/details_meta.dart';
import 'package:forja_foundation/protocol/protocol.dart';

void main() {
  group('hubDetailsParams', () {
    test('prefers open.id over list uniqueId seed.id', () {
      const seed = MetaItem(
        id: 'catalog_test-hub_18842',
        type: 'drama',
        name: 'Drama',
        open: MetaOpen(
          surface: 'drama',
          id: '18842',
          extract: MetaOpenExtract(
            resolveType: 'drama',
            panelCategory: 'drama',
            ctx: {'id': 18842},
          ),
        ),
      );
      final params = hubDetailsParams(seed);
      expect(params['id'], '18842');
    });

    test('falls back to seed.id when open.id empty', () {
      const seed = MetaItem(
        id: 'drama:99',
        type: 'drama',
        name: 'Drama',
        open: MetaOpen(surface: 'drama', id: '  '),
      );
      expect(hubDetailsParams(seed)['id'], 'drama:99');
    });
  });

  group('hubMetaIsUpcoming', () {
    test('reads pack-emitted upcoming only', () {
      const yes = MetaItem(
        id: 't:1',
        type: 'drama',
        name: 'Soon',
        upcoming: true,
      );
      const no = MetaItem(
        id: 't:2',
        type: 'drama',
        name: 'Out',
        upcoming: false,
        status: 'NOT_YET_RELEASED',
      );
      const unset = MetaItem(
        id: 't:3',
        type: 'drama',
        name: 'Unset',
        status: 'NOT_YET_RELEASED',
      );
      expect(hubMetaIsUpcoming(yes), isTrue);
      expect(hubMetaIsUpcoming(no), isFalse);
      expect(hubMetaIsUpcoming(unset), isFalse);
    });
  });

  group('hubMetaPremiereDateLabel', () {
    test('reads pack premiereLabel', () {
      const meta = MetaItem(
        id: 't:1',
        type: 'movie',
        name: 'M',
        premiereLabel: 'Jun 14, 2026',
      );
      expect(hubMetaPremiereDateLabel(meta), 'Jun 14, 2026');
    });
  });

  group('hubMergeDetailsSeed', () {
    test('keeps seed poster when details poster empty', () {
      const details = MetaItem(
        id: '1',
        type: 'tv',
        name: 'A',
        poster: '',
        description: 'new',
      );
      const seed = MetaItem(
        id: '1',
        type: 'tv',
        name: 'A',
        poster: 'https://x/p.jpg',
        description: 'old',
      );
      final merged = hubMergeDetailsSeed(details, seed);
      expect(merged.poster, 'https://x/p.jpg');
      expect(merged.description, 'new');
    });
  });
}
