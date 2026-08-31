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

  group('languageDisplayName', () {
    test('resolves ISO codes that subtitle packs commonly ship', () {
      expect(languageDisplayName('wo'), 'Wolof');
      expect(languageDisplayName('xh'), 'isiXhosa');
      expect(languageDisplayName('yo'), 'Yorùbá');
      expect(languageDisplayName('zu'), 'isiZulu');
      expect(languageDisplayName('is'), 'Íslenska');
    });

    test('resolves OpenSubtitles zt as traditional Chinese', () {
      expect(languageDisplayName('zt'), '中文（繁體）');
    });

    test('does not leave bare two-letter codes as title case', () {
      expect(languageDisplayName('wo'), isNot('Wo'));
      expect(languageDisplayName('xh'), isNot('Xh'));
    });
  });
}
