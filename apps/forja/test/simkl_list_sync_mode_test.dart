import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalDataScope.resetForTest();
    await LocalDataScope.configure(accountId: 'acct-a', profileId: 'prof-1');
  });

  group('listSyncMode storage', () {
    test('round-trips mergeWithDeletion', () {
      expect(
        SimklService.listSyncModeToStorage(SimklListSyncMode.mergeWithDeletion),
        'mergeWithDeletion',
      );
      expect(
        SimklService.listSyncModeFromStorage('mergeWithDeletion'),
        SimklListSyncMode.mergeWithDeletion,
      );
    });

    test('persists mergeWithDeletion via set/get', () async {
      final simkl = SimklService();
      await simkl.setListSyncMode(SimklListSyncMode.mergeWithDeletion);
      expect(
        await simkl.getListSyncMode(),
        SimklListSyncMode.mergeWithDeletion,
      );
    });
  });

  group('import skip by tombstone', () {
    test('skips matching tmdb movie/tv hide keys', () {
      final skip = {
        BookmarkStore.movieId(42, 'tv'),
        BookmarkStore.movieId(7, 'movie'),
      };
      expect(
        SimklService.importRowSkippedByTombstone(
          tmdbId: 42,
          mediaType: 'tv',
          skipHideKeys: skip,
        ),
        isTrue,
      );
      expect(
        SimklService.importRowSkippedByTombstone(
          tmdbId: 42,
          mediaType: 'shows',
          skipHideKeys: skip,
        ),
        isTrue,
      );
      expect(
        SimklService.importRowSkippedByTombstone(
          tmdbId: 99,
          mediaType: 'tv',
          skipHideKeys: skip,
        ),
        isFalse,
      );
    });

    test('skips matching anilist keys', () {
      expect(
        SimklService.importAnimeSkippedByTombstone(
          anilistId: 123,
          skipHideKeys: {'anilist:123'},
        ),
        isTrue,
      );
      expect(
        SimklService.importAnimeSkippedByTombstone(
          anilistId: 123,
          skipHideKeys: {'open:anime:123'},
        ),
        isTrue,
      );
      expect(
        SimklService.importAnimeSkippedByTombstone(
          anilistId: 123,
          skipHideKeys: {'anilist:999'},
        ),
        isFalse,
      );
    });
  });

  group('list delete tombstones', () {
    test('record then listDeleteTombstoneKeys includes movie id', () async {
      final simkl = SimklService();
      await simkl.clearListDeleteTombstones();
      await simkl.recordListDeleteTombstone(
        hideKeys: {BookmarkStore.movieId(55, 'tv')},
        tmdbId: 55,
        mediaType: 'tv',
      );
      final keys = await simkl.listDeleteTombstoneKeys();
      expect(keys, contains(BookmarkStore.movieId(55, 'tv')));
    });

    test('clear matching drops tombstone on re-add', () async {
      final simkl = SimklService();
      await simkl.clearListDeleteTombstones();
      await simkl.recordListDeleteTombstone(
        hideKeys: {BookmarkStore.movieId(55, 'tv')},
        tmdbId: 55,
        mediaType: 'tv',
      );
      await simkl.clearListDeleteTombstonesMatching(tmdbId: 55);
      expect(await simkl.listDeleteTombstoneKeys(), isEmpty);
    });
  });
}
