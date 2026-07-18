import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/ordering/provider_score_memory.dart';
import 'package:rust/src/playback/domain/provider_score_scope.dart';

void main() {
  setUp(ProviderScoreMemory.resetForTest);

  final movie = ProviderScoreScope.movie(tmdbId: 550);
  final tv = ProviderScoreScope.tv(tmdbId: 1399, season: 1, episode: 3);
  final anime = ProviderScoreScope.anime(anilistId: 21, episode: 12);

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

    test('all streams down on working server applies −2 once', () async {
      const urls = ['a', 'b'];
      await ProviderScoreMemory.recordServerUp(movie, 'vixsrc');
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);

      final applied = await ProviderScoreMemory.recordAllStreamsDownIfNeeded(
        scope: movie,
        providerId: 'vixsrc',
        streamUrls: urls,
        isStreamFailed: (_) => true,
      );
      expect(applied, isTrue);
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), 2);
    });
  });
}
