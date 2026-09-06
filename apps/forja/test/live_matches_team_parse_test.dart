import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_schedule/data/live_team_parse.dart';

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

    test('peels event colon before vs', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'UFC Fight Night: Hooker vs Parnasse',
      );
      expect(home, 'Hooker');
      expect(away, 'Parnasse');
    });

    test('peels event number before fighter vs', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'UFC Fight Night 287 Hooker vs Parnasse',
      );
      expect(home, 'Hooker');
      expect(away, 'Parnasse');
    });

    test('UFC colon and numbered titles soft-match as same pair', () {
      final a = parseLiveMatchTeamsFromTitle(
        'UFC Fight Night 287 Hooker vs Parnasse',
      );
      final b = parseLiveMatchTeamsFromTitle(
        'UFC Fight Night: Hooker vs Parnasse',
      );
      expect(liveTeamPairSoftEqual(a.$1, a.$2, b.$1, b.$2), isTrue);
    });

    test('keeps clock times out of event-colon peel', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'Premier League 20:00 Arsenal vs Chelsea',
      );
      expect(home, 'Premier League 20:00 Arsenal');
      expect(away, 'Chelsea');
    });

    test('peels matchday number for football titles', () {
      final (home, away) = parseLiveMatchTeamsFromTitle(
        'Premier League Matchday 28 Arsenal vs Chelsea',
      );
      expect(home, 'Arsenal');
      expect(away, 'Chelsea');
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

  group('liveTeamNamesSoftEqual', () {
    test('matches mascot long form to short form', () {
      expect(
        liveTeamNamesSoftEqual('Colorado', 'Colorado Buffaloes'),
        isTrue,
      );
      expect(
        liveTeamNamesSoftEqual(
          'Georgia Tech',
          'Georgia Tech Yellow Jackets',
        ),
        isTrue,
      );
    });

    test('rejects different schools that share a prefix', () {
      expect(liveTeamNamesSoftEqual('Florida', 'Florida State'), isFalse);
      expect(liveTeamNamesSoftEqual('Georgia', 'Georgia Tech'), isFalse);
      expect(
        liveTeamNamesSoftEqual('Manchester City', 'Manchester United'),
        isFalse,
      );
    });

    test('PPV at-home soft-matches Streamed vs for CFB mascots', () {
      final ppv = parseLiveMatchTeamsFromTitle(
        'Colorado Buffaloes at Georgia Tech Yellow Jackets',
      );
      final streamed = parseLiveMatchTeamsFromTitle(
        'Georgia Tech vs Colorado',
      );
      expect(
        liveTeamPairSoftEqual(ppv.$1, ppv.$2, streamed.$1, streamed.$2),
        isTrue,
      );
    });
  });

  group('liveEventSessionKey', () {
    test('parses Practice N and Nth Practice', () {
      expect(
        liveEventSessionKey('Italian Grand Prix - Practice 2'),
        'practice:2',
      );
      expect(
        liveEventSessionKey('2nd Practice | Autodromo Nazionale Monza |'),
        'practice:2',
      );
      expect(liveEventSessionKey('Italian Grand Prix Practice 1'), 'practice:1');
      expect(liveEventSessionKey('FP3 — Monza'), 'practice:3');
    });
  });

  group('liveEventSessionSoftEqual', () {
    test('unique session matches divergent venue titles', () {
      expect(
        liveEventSessionSoftEqual(
          'Italian Grand Prix - Practice 2',
          '2nd Practice | Autodromo Nazionale Monza |',
          candidateCountForSession: 1,
        ),
        isTrue,
      );
    });

    test('without uniqueness requires shared core tokens', () {
      expect(
        liveEventSessionSoftEqual(
          'Italian Grand Prix - Practice 2',
          '2nd Practice | Autodromo Nazionale Monza |',
          candidateCountForSession: 2,
        ),
        isFalse,
      );
      expect(
        liveEventSessionSoftEqual(
          'Italian Grand Prix Practice 2',
          'Monza Italian Grand Prix Practice 2',
          candidateCountForSession: 2,
        ),
        isTrue,
      );
    });

    test('rejects different session numbers', () {
      expect(
        liveEventSessionSoftEqual(
          'Italian Grand Prix Practice 1',
          '2nd Practice | Autodromo Nazionale Monza |',
          candidateCountForSession: 1,
        ),
        isFalse,
      );
    });
  });
}
