import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/official_forjahq_install.dart';
import 'package:forja/shared/engine/official_forjahq_packs.dart';

void main() {
  group('officialPackCandidatesMissing', () {
    test('skips fully installed urls and empty manifests', () {
      const targets = [
        OfficialForjaHqPack(
          id: 'pack-a',
          name: 'Pack A',
          manifestUrl: 'https://example.test/a/manifest.json',
        ),
        OfficialForjaHqPack(
          id: 'pack-b',
          name: 'Pack B',
          description: 'What Pack B does',
          tags: ['anime'],
          kind: 'hubs',
          manifestUrl: 'https://example.test/b/manifest.json',
        ),
        OfficialForjaHqPack(
          id: 'pack-empty',
          name: 'Empty',
          manifestUrl: '  ',
        ),
      ];

      final candidates = officialPackCandidatesMissing(
        targets: targets,
        fullyInstalledUrls: {'https://example.test/a/manifest.json'},
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.manifestUrl, 'https://example.test/b/manifest.json');
      expect(candidates.single.displayName, 'Pack B');
      expect(candidates.single.description, 'What Pack B does');
      expect(candidates.single.tags, ['anime']);
      expect(candidates.single.catalogKind, 'hubs');
      expect(candidates.single.official, isTrue);
      expect(candidates.single.alreadyInstalled, isFalse);
    });

    test('marks recommended packs and sorts them first', () {
      const targets = [
        OfficialForjaHqPack(
          id: 'kids',
          name: 'ForjaHQ Kids',
          manifestUrl: 'https://example.test/kids/manifest.json',
        ),
        OfficialForjaHqPack(
          id: 'anime',
          name: 'ForjaHQ Anime',
          recommended: true,
          manifestUrl: 'https://example.test/anime/manifest.json',
        ),
        OfficialForjaHqPack(
          id: 'home',
          name: 'ForjaHQ Home',
          recommended: true,
          manifestUrl: 'https://example.test/home/manifest.json',
        ),
      ];

      final candidates = officialPackCandidatesMissing(
        targets: targets,
        fullyInstalledUrls: {},
      );

      expect(candidates, hasLength(3));
      expect(candidates.map((c) => c.displayName).toList(), [
        'ForjaHQ Anime',
        'ForjaHQ Home',
        'ForjaHQ Kids',
      ]);
      expect(candidates[0].recommended, isTrue);
      expect(candidates[1].recommended, isTrue);
      expect(candidates[2].recommended, isFalse);
    });

    test('returns empty when every target is installed', () {
      const targets = [
        OfficialForjaHqPack(
          id: 'pack-a',
          name: 'Pack A',
          manifestUrl: 'https://example.test/a/manifest.json',
        ),
      ];
      final candidates = officialPackCandidatesMissing(
        targets: targets,
        fullyInstalledUrls: {'https://example.test/a/manifest.json'},
      );
      expect(candidates, isEmpty);
    });
  });
}
