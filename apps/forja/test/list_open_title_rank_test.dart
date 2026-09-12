import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/lists/list_open_title_rank.dart';

void main() {
  group('listOpenTitleKey', () {
    test('strips year and punctuation', () {
      expect(listOpenTitleKey('Fight Club (1999)'), 'fight club');
      expect(listOpenTitleKey('Steins;Gate'), 'steins gate');
    });
  });

  group('listOpenRankByTitle', () {
    test('exact same name rises to top', () {
      final ranked = listOpenRankByTitle(
        'Naruto',
        const ['Boruto', 'Naruto Shippuden', 'Naruto', 'Bleach'],
        nameOf: (s) => s,
      );
      expect(ranked.first, 'Naruto');
    });

    test('year boosts matching release', () {
      final ranked = listOpenRankByTitle(
        'Dune',
        const [
          ('Dune', '1984'),
          ('Dune', '2021'),
          ('Dune: Part Two', '2024'),
        ],
        nameOf: (e) => e.$1,
        releaseOf: (e) => e.$2,
        queryYear: 2021,
      );
      expect(ranked.first.$2, '2021');
    });

    test('drops zero-score noise when a real match exists', () {
      final ranked = listOpenRankByTitle(
        'Matrix',
        const ['Completely Unrelated', 'The Matrix', 'Matrix Reloaded'],
        nameOf: (s) => s,
      );
      expect(ranked.any((s) => s == 'Completely Unrelated'), isFalse);
      expect(ranked.first, 'The Matrix');
    });
  });

  group('listOpenIsStrongTitleMatch', () {
    test('exact and same-token order', () {
      expect(listOpenIsStrongTitleMatch('Fight Club', 'Fight Club'), isTrue);
      expect(listOpenIsStrongTitleMatch('Club Fight', 'Fight Club'), isTrue);
      expect(listOpenIsStrongTitleMatch('Fight', 'Fight Club 2'), isFalse);
    });
  });
}
