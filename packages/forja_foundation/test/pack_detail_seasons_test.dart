import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/details/pack_detail_meta.dart';

void main() {
  test('parseKitDetailSeasons reads numbered opaque ids', () {
    final seasons = parseKitDetailSeasons({
      'seasons': [
        {
          'number': 2,
          'id': 'pack:21699',
          'label': 'OVA 1',
          'year': 2019,
          'poster': 'https://cdn.example/ova.jpg',
        },
        {
          'number': 1,
          'id': 'pack:21237',
          'label': 'Season 2 - Part 1',
          'year': 2021,
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
    expect(seasons.first.label, 'Season 2 - Part 1');
    expect(seasons.first.year, 2021);
    expect(seasons.first.selected, isTrue);
    expect(seasons.last.number, 2);
    expect(seasons.last.id, 'pack:21699');
    expect(seasons.last.label, 'OVA 1');
    expect(seasons.last.poster, 'https://cdn.example/ova.jpg');
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

  test('parseKitDetailSeasonPosters reads absolute http urls', () {
    final posters = parseKitDetailSeasonPosters({
      'seasonPosters': {
        '2': 'https://tmdb.forjahq.xyz/t/p/w500/s2.jpg',
        '1': 'https://image.tmdb.org/t/p/w500/s1.jpg',
        '0': 'https://cdn.example/skip.jpg',
        'bad': 'https://cdn.example/x.jpg',
        '3': '/relative.jpg',
        '4': '',
      },
    });
    expect(posters, hasLength(2));
    expect(posters[1], 'https://tmdb.forjahq.xyz/t/p/w500/s1.jpg');
    expect(posters[2], 'https://tmdb.forjahq.xyz/t/p/w500/s2.jpg');
  });

  test('parseKitDetailSeasonPosters empty when omitted', () {
    expect(parseKitDetailSeasonPosters(null), isEmpty);
    expect(parseKitDetailSeasonPosters({}), isEmpty);
    expect(parseKitDetailSeasonPosters({'seasonPosters': []}), isEmpty);
  });
}
