import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('sportCatalogsForLive', () {
    test('includes type sport catalogs', () {
      final catalogs = StremioService.sportCatalogsForLive({
        'manifest': {
          'catalogs': [
            {'type': 'sport', 'id': 'sports_live', 'name': 'Live Now'},
            {'type': 'movie', 'id': 'top', 'name': 'Top'},
          ],
        },
      });
      expect(catalogs, hasLength(1));
      expect(catalogs.first['id'], 'sports_live');
    });

    test('includes type events catalogs', () {
      final catalogs = StremioService.sportCatalogsForLive({
        'manifest': {
          'catalogs': [
            {'type': 'events', 'id': 'sports-events', 'name': 'Events'},
            {'type': 'movie', 'id': 'top', 'name': 'Top'},
          ],
        },
      });
      expect(catalogs, hasLength(1));
      expect(catalogs.first['id'], 'sports-events');
    });

    test('includes live-named tv catalogs', () {
      final catalogs = StremioService.sportCatalogsForLive({
        'manifest': {
          'catalogs': [
            {
              'type': 'tv',
              'id': 'essential-live-events',
              'name': 'Essential Live Events',
            },
          ],
        },
      });
      expect(catalogs, hasLength(1));
      expect(catalogs.first['id'], 'essential-live-events');
    });

    test('prefers sports_live and sports_today when present', () {
      final catalogs = StremioService.sportCatalogsForLive({
        'manifest': {
          'catalogs': [
            {'type': 'sport', 'id': 'sports_football', 'name': 'Football'},
            {'type': 'sport', 'id': 'sports_live', 'name': 'Live Now'},
            {'type': 'sport', 'id': 'sports_today', 'name': 'Today'},
          ],
        },
      });
      expect(catalogs.map((c) => c['id']), ['sports_live', 'sports_today']);
    });
  });
}
