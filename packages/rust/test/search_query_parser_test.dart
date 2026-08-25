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

  group('score and media type', () {
    test('score operators and year range', () {
      final p = parseSearchQuery('>8 <9 2020-2025 films');
      expect(p.minScore, 8);
      expect(p.maxScore, 9);
      expect(p.yearStart, 2020);
      expect(p.yearEnd, 2025);
      expect(p.mediaType, 'movie');
      expect(p.remainder, isEmpty);
    });

    test('score range 8-9', () {
      final p = parseSearchQuery('nolan 8-9');
      expect(p.remainder, 'nolan');
      expect(p.minScore, 8);
      expect(p.maxScore, 9);
    });

    test('series token', () {
      final p = parseSearchQuery('drama series >=7');
      expect(p.mediaType, 'tv');
      expect(p.minScore, 7);
      expect(p.matchedGenreLabel, 'Drama');
    });

    test('gte token', () {
      final p = parseSearchQuery('films >=8.5');
      expect(p.mediaType, 'movie');
      expect(p.minScore, 8.5);
    });

    test('origin country', () {
      final p = parseSearchQuery('horror japan >=8');
      expect(p.matchedGenreLabel, 'Horror');
      expect(p.originCountry, 'JP');
      expect(p.minScore, 8);
      expect(p.remainder, isEmpty);
    });

    test('korea alias', () {
      final p = parseSearchQuery('korea series');
      expect(p.originCountry, 'KR');
      expect(p.mediaType, 'tv');
    });
  });
}
