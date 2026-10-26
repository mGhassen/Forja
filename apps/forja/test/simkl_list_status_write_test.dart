import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseAddToListResponse', () {
    test('reads silent completed → watching rewrite', () {
      final r = SimklService.parseAddToListResponse('''
{
  "added": {
    "shows": [{ "to": "watching", "ids": { "tmdb": 1 }, "type": "show" }]
  },
  "not_found": { "shows": [], "movies": [] }
}
''');
      expect(r.ok, isTrue);
      expect(r.resolvedTo, 'watching');
      expect(r.rewrittenAgainst('completed'), isTrue);
    });

    test('not_found only → fail', () {
      final r = SimklService.parseAddToListResponse('''
{
  "added": { "shows": [], "movies": [] },
  "not_found": { "movies": [{ "title": "Nope" }] }
}
''');
      expect(r.ok, isFalse);
      expect(r.notFound, isTrue);
    });
  });

  group('ListFollow.hideKeysFor', () {
    test('anime includes open:anime and anilist keys', () {
      final t = ListFollowTarget(
        pluginId: 'test-hub-a',
        open: const MetaOpen(surface: 'anime', id: '110349'),
        title: 'Test',
        posterPath: '',
        mediaType: 'anime',
      );
      final keys = ListFollow.hideKeysFor(t);
      expect(keys, contains('open:anime:110349'));
      expect(keys, contains('anilist:110349'));
    });

    test('movie uses tmdb_movie hide key not default tv', () {
      final t = ListFollowTarget(
        pluginId: 'test-hub-b',
        open: const MetaOpen(surface: 'tmdb', id: '603'),
        title: 'Matrix',
        posterPath: '',
        tmdbId: 603,
        tmdbMediaType: 'movie',
        mediaType: 'movie',
      );
      expect(ListFollow.simklListMediaType(t), 'movie');
      final keys = ListFollow.hideKeysFor(t);
      expect(keys, contains(BookmarkStore.movieId(603, 'movie')));
      expect(keys, contains('open:tmdb:603'));
      expect(keys, isNot(contains(BookmarkStore.movieId(603, 'tv'))));
    });
  });
}
