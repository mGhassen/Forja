import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ProviderScoreMemory.resetForTest();
    await EpisodeWatchedService().clearAll();
  });

  test('ProviderScoreMemory.clearAll zeros local scores', () async {
    final scope = ProviderScoreScope.movie(tmdbId: 42);
    await ProviderScoreMemory.recordServerUp(scope, 'videasy');
    expect(ProviderScoreMemory.scoreFor(scope, 'videasy'), greaterThan(0));

    await ProviderScoreMemory.clearAll();
    expect(ProviderScoreMemory.scoreFor(scope, 'videasy'), 0);
  });

  test('EpisodeWatchedService.clearAll removes flags', () async {
    final svc = EpisodeWatchedService();
    await svc.setWatchedLocal(1, 1, 1, true);
    expect(await svc.isWatched(1, 1, 1), isTrue);

    await svc.clearAll();
    expect(await svc.isWatched(1, 1, 1), isFalse);
  });

  test('EpisodeWatchedService catalog keys stay namespaced', () async {
    final svc = EpisodeWatchedService();
    var synced = 0;
    svc.syncHandler = (_, _, _, _) => synced++;

    await svc.toggle(
      42,
      1,
      3,
      catalog: EpisodeWatchedService.catalogAnilist,
    );
    expect(
      await svc.isWatched(
        42,
        1,
        3,
        catalog: EpisodeWatchedService.catalogAnilist,
      ),
      isTrue,
    );
    // Same numeric id without catalog must not collide.
    expect(await svc.isWatched(42, 1, 3), isFalse);
    expect(
      await svc.getWatchedSet(
        42,
        catalog: EpisodeWatchedService.catalogAnilist,
      ),
      contains('anilist_42_S1_E3'),
    );
    expect(synced, 0);

    await svc.toggle(42, 1, 3);
    expect(await svc.isWatched(42, 1, 3), isTrue);
    expect(synced, 1);

    svc.syncHandler = null;
  });
}
