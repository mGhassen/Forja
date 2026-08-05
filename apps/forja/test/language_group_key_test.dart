import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/utils/language_display.dart';

void main() {
  group('languageGroupKey', () {
    test('merges ISO + English aliases into one folder key', () {
      expect(languageGroupKey('en'), 'en');
      expect(languageGroupKey('eng'), 'en');
      expect(languageGroupKey('English'), 'en');
      expect(languageGroupKey('ENGLISH'), 'en');
      expect(languageGroupKey('English [Forced]'), 'en');
    });

    test('merges French aliases', () {
      expect(languageGroupKey('fr'), 'fr');
      expect(languageGroupKey('fra'), 'fr');
      expect(languageGroupKey('French'), 'fr');
      expect(languageGroupKey('français'), 'fr');
    });

    test('keeps regional Portuguese distinct when known', () {
      expect(languageGroupKey('pt-br'), 'pt-br');
      expect(languageGroupKey('pt'), 'pt');
      expect(languageGroupKey('Portuguese'), 'pt');
    });

    test('empty / unknown', () {
      expect(languageGroupKey(null), 'unknown');
      expect(languageGroupKey(''), 'unknown');
      expect(languageGroupKey('   '), 'unknown');
    });
  });
}
