import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/details/pack_detail_meta.dart';

void main() {
  test('parseKitDetailSeasons reads numbered opaque ids', () {
    final seasons = parseKitDetailSeasons({
      'seasons': [
        {'number': 2, 'id': 'pack:21699', 'label': 'Season 2'},
        {
          'number': 1,
          'id': 'pack:21237',
          'label': 'Season 1',
          'selected': true,
        },
        {'number': 0, 'id': 'bad'},
        {'number': 1, 'id': 'dup'},
        'skip',
      ],
    });
    expect(seasons, hasLength(2));
    expect(seasons.first.number, 1);
    expect(seasons.first.id, 'pack:21237');
    expect(seasons.first.selected, isTrue);
    expect(seasons.last.number, 2);
    expect(seasons.last.id, 'pack:21699');
  });

  test('parseKitDetailSeasons empty when omitted or short', () {
    expect(parseKitDetailSeasons(null), isEmpty);
    expect(parseKitDetailSeasons({}), isEmpty);
    expect(
      parseKitDetailSeasons({
        'seasons': [
          {'number': 1, 'id': 'only'},
        ],
      }),
      hasLength(1),
    );
  });
}
