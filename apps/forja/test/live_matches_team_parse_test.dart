import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_matches_team_parse.dart';

void main() {
  group('parseLiveMatchTeamsFromTitle', () {
    test('parses visitor at home', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'Las Vegas Raiders at Houston Texans',
      );
      expect(home, 'Houston Texans');
      expect(away, 'Las Vegas Raiders');
    });

    test('parses vs', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'Tampa Bay Rays vs Toronto Blue Jays',
      );
      expect(home, 'Tampa Bay Rays');
      expect(away, 'Toronto Blue Jays');
    });

    test('parses @ and strips emoji', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'Boston Red Sox @ Yankees 🎾',
      );
      expect(home, 'Yankees');
      expect(away, 'Boston Red Sox');
    });

    test('tournament / network titles have no teams', () {
      expect(
        parseLiveMatchTeamsFromTitle('ATP / WTA Cincinnati Open  🎾'),
        ('', ''),
      );
      expect(parseLiveMatchTeamsFromTitle('NFL Network'), ('', ''));
    });
  });
}
