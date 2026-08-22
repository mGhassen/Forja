import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/parental_guide/parental_guide_service.dart';

void main() {
  test('extractParentalGuideImdbId strips season tokens', () {
    expect(extractParentalGuideImdbId('tt15398776'), 'tt15398776');
    expect(extractParentalGuideImdbId('tt15398776:1:2'), 'tt15398776');
    expect(extractParentalGuideImdbId('series:tt15398776:1:2'), 'tt15398776');
    expect(extractParentalGuideImdbId(null), isNull);
    expect(extractParentalGuideImdbId('tmdb:123'), isNull);
  });

  test('resolveParentalGuideSeverity picks dominant non-none votes', () {
    expect(
      resolveParentalGuideSeverity({
        'severityBreakdowns': [
          {'severityLevel': 'none', 'voteCount': 317},
          {'severityLevel': 'mild', 'voteCount': 672},
          {'severityLevel': 'moderate', 'voteCount': 2521},
          {'severityLevel': 'severe', 'voteCount': 2329},
        ],
      }),
      'moderate',
    );
  });

  test('resolveParentalGuideSeverity ignores none-majority', () {
    expect(
      resolveParentalGuideSeverity({
        'severityBreakdowns': [
          {'severityLevel': 'none', 'voteCount': 90},
          {'severityLevel': 'mild', 'voteCount': 10},
        ],
      }),
      isNull,
    );
  });

  test('buildParentalWarnings sorts severe first and drops none', () {
    final warnings = buildParentalWarnings(
      const ParentalGuideResult(
        nudity: 'severe',
        violence: 'mild',
        profanity: 'moderate',
        alcohol: null,
        frightening: 'severe',
      ),
    );
    expect(warnings.map((w) => '${w.label} ${w.severity}').toList(), [
      'Nudity severe',
      'Frightening severe',
      'Profanity moderate',
      'Violence mild',
    ]);
  });

  test('mapParentalGuideCategories reads tiffara keys', () {
    final result = mapParentalGuideCategories([
      {
        'category': 'SEXUAL_CONTENT',
        'severityBreakdowns': [
          {'severityLevel': 'mild', 'voteCount': 5},
          {'severityLevel': 'none', 'voteCount': 1},
        ],
      },
      {
        'category': 'VIOLENCE',
        'severityBreakdowns': [
          {'severityLevel': 'severe', 'voteCount': 9},
          {'severityLevel': 'none', 'voteCount': 0},
        ],
      },
    ]);
    expect(result.nudity, 'mild');
    expect(result.violence, 'severe');
    expect(result.profanity, isNull);
  });
}
