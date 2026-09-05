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
      expect(candidates.single.alreadyInstalled, isFalse);
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
