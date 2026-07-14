import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProviderScoreMemory.resetForTest();
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
}
