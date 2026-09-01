import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/services/hub_list_follow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HubListFollow.resolveSimklTarget', () {
    CatalogListFollowTarget dramaTarget({int? tmdbId}) {
      return CatalogListFollowTarget(
        pluginId: 'test-drama-hub',
        open: const CatalogOpen(
          surface: 'drama',
          id: '42',
          extract: CatalogOpenExtract(
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
      expect(HubListFollow.resolveSimklTarget(t).tmdbId, 99);
    });

    test('returns target unchanged when drama has no stored TMDB', () {
      final t = dramaTarget();
      expect(HubListFollow.resolveSimklTarget(t).tmdbId, isNull);
    });
  });
}
