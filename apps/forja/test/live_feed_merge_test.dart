import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_feed_merge.dart';
import 'package:forja/shared/engine/live/live_fixture_match.dart';
import 'package:forja/shared/engine/live/match_event.dart';
import 'package:forja_foundation/protocol/protocol.dart';

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

      // List / cards paint MetaItem + MatchEvent from the merged row.
      final shaped = Map<String, dynamic>.from(merged.first);
      shaped['name'] = shaped['title'];
      shaped['type'] = 'live_match';
      expect(MetaItem.fromJson(shaped).viewers, 11904 + 2846);
      expect(
        MatchEvent.fromLegacyRow(merged.first).viewers,
        11904 + 2846,
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

    test('unions broadcastChannels from guide sibling onto stream card', () {
      final kick = DateTime(2026, 9, 10, 20).millisecondsSinceEpoch;
      final merged = mergeLiveFeedMatchingRows([
        {
          'id': 'streamed-1',
          'title': 'Barcelona vs Real Madrid',
          'homeTeam': 'Barcelona',
          'awayTeam': 'Real Madrid',
          'category': 'La Liga',
          'date': kick,
          'airing': true,
          'poster': 'https://example.com/crest.png',
          'sources': [
            {'source': 'streamed', 'id': '1'},
          ],
          'sportMatchGame': {
            'title': 'Barcelona vs Real Madrid',
            'homeTeam': 'Barcelona',
            'awayTeam': 'Real Madrid',
          },
        },
        {
          'id': 'guide-1',
          'title': 'Barcelona vs Real Madrid',
          'homeTeam': 'Barcelona',
          'awayTeam': 'Real Madrid',
          'category': 'Football',
          'date': kick,
          'airing': true,
          'sportMatchGame': {
            'title': 'Barcelona vs Real Madrid',
            'homeTeam': 'Barcelona',
            'awayTeam': 'Real Madrid',
            'broadcastChannels': ['Sky Sports Main Event', 'DAZN 1'],
          },
        },
      ]);
      expect(merged, hasLength(1));
      final channels = liveBroadcastChannelsFromRow(merged.first);
      expect(channels, containsAll(['Sky Sports Main Event', 'DAZN 1']));
      final game = merged.first['sportMatchGame'] as Map;
      expect(game['broadcastChannels'], containsAll(['Sky Sports Main Event', 'DAZN 1']));
      expect(merged.first['sources'], hasLength(1));
    });
  });

  group('liveBroadcastChannelsFromRow', () {
    test('reads top-level and sportMatchGame lists', () {
      expect(
        liveBroadcastChannelsFromRow({
          'broadcastChannels': ['beIN Sports 1'],
          'sportMatchGame': {
            'broadcastChannels': ['TNT Sports 1', 'beIN Sports 1'],
          },
        }),
        ['beIN Sports 1', 'TNT Sports 1'],
      );
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