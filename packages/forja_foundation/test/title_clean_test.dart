import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/utils/title_clean.dart';

void main() {
  group('cleanMediaTitle', () {
    test('strips empty pipe prefixes', () {
      expect(cleanMediaTitle('| | The Runner').title, 'The Runner');
    });

    test('strips pipe-wrapped lang tags', () {
      expect(cleanMediaTitle('|EN| The Runner').title, 'The Runner');
      expect(cleanMediaTitle('|FR| |EN| The Runner').title, 'The Runner');
    });

    test('strips quality and dashed tags', () {
      expect(
        cleanMediaTitle('EN | 4K | The Runner').title,
        'The Runner',
      );
      expect(
        cleanMediaTitle('EN-NETFLIX-The Runner (2024)').title,
        'The Runner',
      );
      expect(
        cleanMediaTitle('EN-NETFLIX-The Runner (2024)').year,
        2024,
      );
    });
  });
}
