import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ListFollow.resolveSimklTarget', () {
    ListFollowTarget dramaTarget({int? tmdbId}) {
      return ListFollowTarget(
        pluginId: 'test-drama-hub',
        open: const MetaOpen(
          surface: 'drama',
          id: '42',
          extract: MetaOpenExtract(
            resolveType: 'drama',
            panelCategory: 'drama',
            ctx: {'kisskhId': 42},
          ),
        ),
        title: 'Test Drama',
        posterPath: '',
        mediaType: 'drama',
        tmdbId: tmdbId,
      );
    }

    test('returns target unchanged when TMDB is on meta', () {
      final t = dramaTarget(tmdbId: 99);
      expect(ListFollow.resolveSimklTarget(t).tmdbId, 99);
    });

    test('returns target unchanged when drama has no stored TMDB', () {
      final t = dramaTarget();
      expect(ListFollow.resolveSimklTarget(t).tmdbId, isNull);
    });
  });
}
