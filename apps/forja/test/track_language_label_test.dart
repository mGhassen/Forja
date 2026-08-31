import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/player/track_auto_select.dart';

void main() {
  group('trackLanguageEndonym', () {
    test('prefers mux title over wrong lang tag', () {
      expect(
        trackLanguageEndonym(language: 'la', title: 'English'),
        'English',
      );
      expect(
        trackLanguageEndonym(language: 'sv', title: 'Hindi'),
        'हिन्दी',
      );
    });

    test('does not guess endonym for unreliable bare la/sv/no tags', () {
      expect(trackLanguageEndonym(language: 'la'), isNull);
      expect(trackLanguageEndonym(language: 'sv'), isNull);
      expect(trackLanguageEndonym(language: 'no'), isNull);
    });

    test('keeps trustworthy two-letter tags', () {
      expect(trackLanguageEndonym(language: 'en'), 'English');
      expect(trackLanguageEndonym(language: 'es'), 'Español');
      expect(trackLanguageEndonym(language: 'hi'), 'हिन्दी');
    });

    test('keeps three-letter ISO tags', () {
      expect(trackLanguageEndonym(language: 'eng'), 'English');
      expect(trackLanguageEndonym(language: 'hin'), 'हिन्दी');
    });
  });

  group('formatPlayerTrackLabel', () {
    test('uses endonym for trustworthy language codes', () {
      expect(
        formatPlayerTrackLabel(id: '1', language: 'en'),
        'English',
      );
    });

    test('falls back to Audio index for unreliable tags', () {
      expect(
        formatPlayerTrackLabel(id: '1', language: 'la', index: 1),
        'Audio 1',
      );
      expect(
        formatPlayerTrackLabel(id: '2', language: 'sv', index: 2),
        'Audio 2',
      );
    });

    test('prefers title when language is unknown', () {
      expect(
        formatPlayerTrackLabel(
          id: '2',
          title: 'Commentary',
          language: 'und',
        ),
        'Commentary',
      );
    });
  });
}
