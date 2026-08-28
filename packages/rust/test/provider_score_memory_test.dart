import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/ordering/provider_score_memory.dart';
import 'package:rust/src/playback/domain/provider_score_scope.dart';

void main() {
  setUp(ProviderScoreMemory.resetForTest);

  final movie = ProviderScoreScope.movie(tmdbId: 550);
  final tv = ProviderScoreScope.tv(tmdbId: 1399, season: 1, episode: 3);

  group('ProviderScoreMemory scoped scoring', () {
    test('settings base is 0 per title', () {
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 0);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), isNull);
    });

    test('server ok + stream ok adds +2 +2 = +4', () async {
      await ProviderScoreMemory.recordServerUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.serverVerdictFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(movie, 'vixsrc'), isNull);
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);
      expect(ProviderScoreMemory.serverVerdictFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), 2);
    });

    test('film scores are isolated per tmdb id', () async {
      final other = ProviderScoreScope.movie(tmdbId: 999);
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.scoreFor(other, 'vixsrc'), 0);
    });

    test('global score sums title totals for the same provider', () async {
      final other = ProviderScoreScope.movie(tmdbId: 999);
      await ProviderScoreMemory.recordServerUp(movie, 'vixsrc');
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      await ProviderScoreMemory.recordServerUp(other, 'vixsrc');
      await ProviderScoreMemory.recordStreamUp(other, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);
      expect(ProviderScoreMemory.scoreFor(other, 'vixsrc'), 4);
      expect(ProviderScoreMemory.globalScoreFor('vixsrc'), 8);
      expect(ProviderScoreMemory.globalScoreFor('vidlink'), 0);
    });

    test('negative title totals reduce global score', () async {
      for (final id in [1, 2, 3, 4, 5]) {
        final scope = ProviderScoreScope.movie(tmdbId: id);
        await ProviderScoreMemory.recordServerUp(scope, 'megaplay');
        await ProviderScoreMemory.recordStreamUp(scope, 'megaplay');
      }
      await ProviderScoreMemory.recordServerUp(
        ProviderScoreScope.movie(tmdbId: 6),
        'megaplay',
      );
      expect(ProviderScoreMemory.globalScoreFor('megaplay'), 22);

      final fail = ProviderScoreScope.movie(tmdbId: 7);
      await ProviderScoreMemory.recordServerFailure(fail, 'megaplay');
      await ProviderScoreMemory.recordStreamFail(fail, 'megaplay');
      expect(ProviderScoreMemory.scoreFor(fail, 'megaplay'), -4);
      expect(ProviderScoreMemory.serverVerdictFor(fail, 'megaplay'), -2);
      expect(ProviderScoreMemory.streamVerdictFor(fail, 'megaplay'), -2);
      expect(ProviderScoreMemory.globalScoreFor('megaplay'), 18);
    });

    test('global score floors at zero', () async {
      final cold = ProviderScoreScope.movie(tmdbId: 1);
      await ProviderScoreMemory.recordServerFailure(cold, 'cold');
      await ProviderScoreMemory.recordStreamFail(cold, 'cold');
      expect(ProviderScoreMemory.scoreFor(cold, 'cold'), -4);
      expect(ProviderScoreMemory.globalScoreFor('cold'), 0);
      expect(ProviderScoreMemory.allGlobalScores().containsKey('cold'), isFalse);
    });

    test('fail then up on same title does not inflate global Σ', () async {
      final scope = ProviderScoreScope.anime(anilistId: 21, episode: 1);
      await ProviderScoreMemory.recordStreamFail(scope, 'anikoto');
      await ProviderScoreMemory.recordServerUp(scope, 'anikoto');
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'anikoto'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(scope, 'anikoto'), -2);
      expect(ProviderScoreMemory.scoreFor(scope, 'anikoto'), 0);
      expect(ProviderScoreMemory.globalScoreFor('anikoto'), 0);

      ProviderScoreMemory.resetForTest();
      await ProviderScoreMemory.recordServerUp(scope, 'anikoto');
      await ProviderScoreMemory.recordStreamFail(scope, 'anikoto');
      expect(ProviderScoreMemory.globalScoreFor('anikoto'), 0);
    });

    test('fails at zero do not erase later ups', () async {
      await ProviderScoreMemory.recordServerFailure(
        ProviderScoreScope.anime(anilistId: 1, episode: 1),
        'miruro:bee',
      );
      await ProviderScoreMemory.recordServerFailure(
        ProviderScoreScope.anime(anilistId: 2, episode: 1),
        'miruro:bee',
      );
      expect(ProviderScoreMemory.globalScoreFor('miruro:bee'), 0);
      final win = ProviderScoreScope.anime(anilistId: 3, episode: 1);
      await ProviderScoreMemory.recordServerUp(win, 'miruro:bee');
      await ProviderScoreMemory.recordStreamUp(win, 'miruro:bee');
      expect(ProviderScoreMemory.globalScoreFor('miruro:bee'), 4);
      await ProviderScoreMemory.recordServerFailure(
        ProviderScoreScope.anime(anilistId: 4, episode: 1),
        'miruro:bee',
      );
      expect(ProviderScoreMemory.globalScoreFor('miruro:bee'), 2);
    });

    test('tv scores are per season and episode', () async {
      final otherEp = ProviderScoreScope.tv(
        tmdbId: 1399,
        season: 1,
        episode: 4,
      );
      await ProviderScoreMemory.recordServerUp(tv, 'vidlink');
      expect(ProviderScoreMemory.scoreFor(tv, 'vidlink'), 2);
      expect(ProviderScoreMemory.scoreFor(otherEp, 'vidlink'), 0);
    });

    test('stream fail does not erase sticky stream-up verdict', () async {
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      await ProviderScoreMemory.recordStreamFail(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), 2);
    });

    test('all streams down on working server keeps sticky stream-up', () async {
      const urls = ['a', 'b'];
      await ProviderScoreMemory.recordLinkedStreamsUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);

      final applied = await ProviderScoreMemory.recordAllStreamsDownIfNeeded(
        scope: movie,
        providerId: 'vixsrc',
        streamUrls: urls,
        isStreamFailed: (_) => true,
      );
      expect(applied, isTrue);
      // Stream-up is sticky — later all-down does not erase a proven stream.
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);
      expect(ProviderScoreMemory.streamVerdictFor(movie, 'vixsrc'), 2);
    });

    test('all streams down without prior stream-up commits linked +2−2', () async {
      final applied = await ProviderScoreMemory.recordAllStreamsDownIfNeeded(
        scope: movie,
        providerId: 'anikoto',
        streamUrls: const ['a'],
        isStreamFailed: (_) => true,
      );
      expect(applied, isTrue);
      expect(ProviderScoreMemory.serverVerdictFor(movie, 'anikoto'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(movie, 'anikoto'), -2);
      expect(ProviderScoreMemory.scoreFor(movie, 'anikoto'), 0);
      expect(ProviderScoreMemory.globalScoreFor('anikoto'), 0);
    });
  });
}
