import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/catalog/search_query_parser.dart';

void main() {
  group('parseSearchQuery', () {
    test('plain title unchanged', () {
      final p = parseSearchQuery('inception');
      expect(p.remainder, 'inception');
      expect(p.year, isNull);
      expect(p.hasGenre, isFalse);
    });

    test('person + year', () {
      final p = parseSearchQuery('nolan 2025');
      expect(p.remainder, 'nolan');
      expect(p.year, 2025);
      expect(p.yearBounds, (2025, 2025));
    });

    test('person + year range', () {
      final p = parseSearchQuery('Nolan 2022-2025');
      expect(p.remainder, 'Nolan');
      expect(p.yearStart, 2022);
      expect(p.yearEnd, 2025);
      expect(p.year, isNull);
      expect(p.yearBounds, (2022, 2025));
    });

    test('year range with spaces and en-dash', () {
      final p = parseSearchQuery('nolan 2022 – 2025');
      expect(p.remainder, 'nolan');
      expect(p.yearBounds, (2022, 2025));
    });

    test('genre + year', () {
      final p = parseSearchQuery('horror 2025');
      expect(p.remainder, isEmpty);
      expect(p.matchedGenreLabel, 'Horror');
      expect(p.movieGenreIds, [27]);
      expect(p.tvGenreIds, isEmpty);
      expect(p.year, 2025);
    });

    test('sci-fi alias', () {
      final p = parseSearchQuery('sci-fi 2024');
      expect(p.matchedGenreLabel, 'Science Fiction');
      expect(p.movieGenreIds, [878]);
      expect(p.tvGenreIds, [10765]);
      expect(p.year, 2024);
      expect(p.remainder, isEmpty);
    });

    test('genre + person + year', () {
      final p = parseSearchQuery('nolan horror 2022');
      expect(p.matchedGenreLabel, 'Horror');
      expect(p.remainder, 'nolan');
      expect(p.year, 2022);
    });

    test('year only', () {
      final p = parseSearchQuery('2025');
      expect(p.remainder, isEmpty);
      expect(p.year, 2025);
      expect(p.hasPersonCandidate, isFalse);
    });

    test('title + year keeps title remainder', () {
      final p = parseSearchQuery('dune 2021');
      expect(p.remainder, 'dune');
      expect(p.year, 2021);
      expect(p.hasGenre, isFalse);
    });
  });

  group('releaseDateInYearBounds', () {
    test('inclusive range', () {
      expect(releaseDateInYearBounds('2023-07-21', (2022, 2025)), isTrue);
      expect(releaseDateInYearBounds('2021-01-01', (2022, 2025)), isFalse);
      expect(releaseDateInYearBounds('2025', (2025, 2025)), isTrue);
      expect(releaseDateInYearBounds('', (2025, 2025)), isFalse);
    });
  });
}
