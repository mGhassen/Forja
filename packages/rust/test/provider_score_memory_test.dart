import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/provider_score_memory.dart';
import 'package:rust/src/playback/provider_score_scope.dart';

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
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 4);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), 2);
    });

    test('film scores are isolated per tmdb id', () async {
      final other = ProviderScoreScope.movie(tmdbId: 999);
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.scoreFor(other, 'vixsrc'), 0);
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

    test('stream fail is −2', () async {
      await ProviderScoreMemory.recordStreamUp(movie, 'vixsrc');
      await ProviderScoreMemory.recordStreamFail(movie, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 0);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), -2);
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
      expect(ProviderScoreMemory.scoreFor(movie, 'vixsrc'), 2);
      expect(ProviderScoreMemory.lastDeltaFor(movie, 'vixsrc'), -2);
    });
  });
}
