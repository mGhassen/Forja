import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_feed_merge.dart';
import 'package:forja/shared/engine/live/live_fixture_match.dart';

void main() {
  group('liveCatalogEventsSoftMatch', () {
    test('soft-matches Barcelona title variants', () {
      expect(
        liveCatalogEventsSoftMatch(
          idA: 'a',
          titleA: 'Feyenoord Rotterdam at Barcelona',
          homeTeamA: null,
          awayTeamA: null,
          dateMsA: 1000,
          idB: 'b',
          titleB: 'Barcelona vs Feyenoord',
          homeTeamB: null,
          awayTeamB: null,
          dateMsB: 1000,
        ),
        isTrue,
      );
      expect(
        liveCatalogEventsSoftMatch(
          idA: 'a',
          titleA: 'Barcelona vs. Feyenoord Rotterdam',
          homeTeamA: null,
          awayTeamA: null,
          dateMsA: 1000,
          idB: 'b',
          titleB: 'Barcelona - Feyenoord',
          homeTeamB: null,
          awayTeamB: null,
          dateMsB: 1000 + const Duration(minutes: 11).inMilliseconds,
        ),
        isTrue,
      );
      expect(
        liveCatalogEventsSoftMatch(
          idA: 'a',
          titleA: 'FC Barcelona vs Feyenoord',
          homeTeamA: null,
          awayTeamA: null,
          dateMsA: 1000,
          idB: 'b',
          titleB: 'Barcelona v Feyenoord',
          homeTeamB: null,
          awayTeamB: null,
          dateMsB: 1000,
        ),
        isTrue,
      );
    });

    test('rejects different fixtures that share a city token', () {
      expect(
        liveCatalogEventsSoftMatch(
          idA: 'a',
          titleA: 'Manchester City vs Arsenal',
          homeTeamA: null,
          awayTeamA: null,
          dateMsA: 1000,
          idB: 'b',
          titleB: 'Manchester United vs Arsenal',
          homeTeamB: null,
          awayTeamB: null,
          dateMsB: 1000,
        ),
        isFalse,
      );
    });
  });

  group('mergeLiveFeedMatchingRows', () {
    test('collapses eight Barcelona catalog variants into one', () {
      final kick = DateTime(2026, 9, 9, 17, 45).millisecondsSinceEpoch;
      final rows = [
        {
          'id': '1',
          'title': 'Feyenoord Rotterdam at Barcelona',
          'category': 'Champions League',
          'date': kick,
          'airing': true,
          'poster': 'https://example.com/crest.png',
          'sources': [
            {'source': 'ppv', 'id': '1'},
          ],
        },
        {
          'id': '2',
          'title': 'Barcelona vs Feyenoord',
          'category': 'Football',
          'date': kick,
          'airing': true,
          'sources': [
            {'source': 'streamed', 'id': '2'},
          ],
        },
        {
          'id': '3',
          'title': 'Barcelona v Feyenoord',
          'category': 'Football',
          'date': kick,
          'airing': true,
        },
        {
          'id': '4',
          'title': 'Barcelona vs. Feyenoord Rotterdam',
          'category': 'Football',
          'date': kick,
          'airing': true,
          'viewers': 11904,
          'poster': 'https://example.com/graphic.png',
        },
        {
          'id': '5',
          'title': 'Feyenoord Rotterdam vs Barcelona',
          'category': 'Football',
          'date': kick,
          'airing': true,
          'viewers': 2846,
        },
        {
          'id': '6',
          'title': 'Barcelona vs Feyenoord',
          'category': 'Football',
          'date': kick,
          'airing': true,
        },
        {
          'id': '7',
          'title': 'Barcelona - Feyenoord',
          'category': 'Football',
          'date': kick + const Duration(minutes: 11).inMilliseconds,
          'airing': true,
        },
        {
          'id': '8',
          'title': 'FC Barcelona vs Feyenoord',
          'category': 'Football',
          'date': kick,
          'airing': true,
        },
      ];

      final merged = mergeLiveFeedMatchingRows(rows);
      expect(merged, hasLength(1));
      expect(merged.first['viewers'], 11904 + 2846);
      final sources = merged.first['sources'] as List;
      expect(sources, hasLength(2));
      expect(
        (merged.first['category'] as String).toLowerCase(),
        contains('champions'),
      );
    });

    test('coarse bucket still keeps City vs United separate', () {
      final kick = DateTime(2026, 9, 9, 15).millisecondsSinceEpoch;
      final merged = mergeLiveFeedMatchingRows([
        {
          'id': '1',
          'title': 'Manchester City vs Arsenal',
          'category': 'Football',
          'date': kick,
          'airing': true,
        },
        {
          'id': '2',
          'title': 'Manchester United vs Arsenal',
          'category': 'Football',
          'date': kick,
          'airing': true,
        },
      ]);
      expect(merged, hasLength(2));
    });
  });

  group('liveEventMergeBucketKey', () {
    test('short and long Feyenoord share a coarse bucket', () {
      expect(
        liveEventMergeBucketKey(
          homeTeam: null,
          awayTeam: null,
          title: 'Barcelona vs Feyenoord',
        ),
        liveEventMergeBucketKey(
          homeTeam: null,
          awayTeam: null,
          title: 'Feyenoord Rotterdam at Barcelona',
        ),
      );
    });
  });
}
