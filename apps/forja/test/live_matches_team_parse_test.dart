import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_team_parse.dart';

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

    test('at and vs reverse to the same home/away', () {
      final at = parseLiveMatchTeamsFromTitle(
        'Houston Texans at Carolina Panthers',
      );
      final vs = parseLiveMatchTeamsFromTitle(
        'Carolina Panthers vs Houston Texans',
      );
      expect(at, ('Carolina Panthers', 'Houston Texans'));
      expect(vs, at);
    });

    test('resolveLiveMatchTeams fills from title when structured empty', () {
      final (home, away) = resolveLiveMatchTeams(
        title: 'Houston Texans at Carolina Panthers',
      );
      expect(home, 'Carolina Panthers');
      expect(away, 'Houston Texans');
    });

    test('resolveLiveMatchTeams keeps structured teams', () {
      final (home, away) = resolveLiveMatchTeams(
        homeTeam: 'Home FC',
        awayTeam: 'Away FC',
        title: 'Ignored at Title',
      );
      expect(home, 'Home FC');
      expect(away, 'Away FC');
    });

    test('foldLiveMatchLatin strips accents', () {
      expect(foldLiveMatchLatin('León'), 'leon');
      expect(foldLiveMatchLatin('Atlético'), 'atletico');
    });

    test('sportNickFromTeam skips generic City suffix', () {
      expect(sportNickFromTeam('Stoke City'), 'Stoke');
      expect(sportNickFromTeam('Norwich City'), 'Norwich');
      expect(sportNickFromTeam('Manchester United'), 'Manchester');
    });
  });
}
