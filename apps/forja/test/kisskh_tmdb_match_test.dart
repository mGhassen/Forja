import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';

void main() {
  group('KissKhTmdbMatch.normalizeTitle', () {
    test('strips trailing year parentheses', () {
      expect(
        KissKhTmdbMatch.normalizeTitle('Queen of Tears (2024)'),
        'Queen of Tears',
      );
    });

    test('strips HD tags and pipe suffixes', () {
      expect(
        KissKhTmdbMatch.normalizeTitle('Crash Landing on You HD | KissKH'),
        'Crash Landing on You',
      );
    });

    test('keeps clean titles', () {
      expect(KissKhTmdbMatch.normalizeTitle('  Squid Game  '), 'Squid Game');
    });
  });

  group('KissKhTmdbMatch.preferMovie', () {
    test('film and hollywood prefer movie', () {
      expect(KissKhTmdbMatch.preferMovie('Movie'), isTrue);
      expect(KissKhTmdbMatch.preferMovie('Hollywood'), isTrue);
      expect(KissKhTmdbMatch.preferMovie('Drama'), isFalse);
      expect(KissKhTmdbMatch.preferMovie(null), isFalse);
    });
  });
}
