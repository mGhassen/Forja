import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/models/plugin_language.dart';

void main() {
  group('PluginLanguage', () {
    test('parse + labels', () {
      expect(
        PluginLanguage.tryParse({'kind': 'sub', 'code': 'fr'})?.label,
        'VOSTFR',
      );
      expect(
        PluginLanguage.tryParse({'kind': 'sub', 'code': 'en'})?.label,
        'VOST',
      );
      expect(
        PluginLanguage.tryParse({'kind': 'dub', 'code': 'fr'})?.label,
        'VF',
      );
      expect(
        PluginLanguage.tryParse({'kind': 'dub', 'code': 'en'})?.label,
        'VO',
      );
      expect(
        PluginLanguage.tryParse({'kind': 'dub', 'code': 'ar'})?.label,
        'Arabic',
      );
      expect(PluginLanguage.tryParseKey('sub:it')?.label, 'VOSTIT');
      expect(PluginLanguage.tryParse({'kind': 'raw', 'code': 'en'}), isNull);
    });
  });

  group('PluginStreamLanguages.overlayLocalProviderLanguages', () {
    test('stamps languages from local map onto matching ids', () {
      final packs = [
        EnginePack(
          sourceUrl: 'https://example.test/manifest.json',
          packId: 'test-pack',
          name: 'Test',
          version: '1',
          plugins: [
            EnginePlugin(
              id: 'test-provider-a',
              name: 'A',
              entry: 'a.js',
              types: const ['anime'],
            ),
            EnginePlugin(
              id: 'test-provider-b',
              name: 'B',
              entry: 'b.js',
              types: const ['anime'],
              languages: const [
                PluginLanguage(kind: 'sub', code: 'en'),
              ],
            ),
          ],
        ),
      ];
      // No FORJA_PACKS_ROOT in unit tests → overlay is a no-op identity.
      final out = PluginStreamLanguages.overlayLocalProviderLanguages(packs);
      expect(out, hasLength(1));
      expect(out.first.plugins.first.languages, isEmpty);
      expect(out.first.plugins[1].languages, hasLength(1));
    });
  });

  group('PluginStreamLanguages.audioCategoryFromKeys', () {
    test('empty → null', () {
      expect(PluginStreamLanguages.audioCategoryFromKeys({}), isNull);
    });

    test('all dub → dub', () {
      expect(
        PluginStreamLanguages.audioCategoryFromKeys({'dub:en', 'dub:fr'}),
        'dub',
      );
    });

    test('all sub → sub', () {
      expect(
        PluginStreamLanguages.audioCategoryFromKeys({'sub:fr'}),
        'sub',
      );
    });

    test('mixed kinds → null', () {
      expect(
        PluginStreamLanguages.audioCategoryFromKeys({'sub:fr', 'dub:en'}),
        isNull,
      );
    });
  });

  group('PluginStreamLanguages.pluginMatches', () {
    EnginePlugin plugin(List<PluginLanguage> langs) => EnginePlugin(
          id: 'test-provider-a',
          name: 'A',
          entry: 'a.js',
          languages: langs,
        );

    test('empty selection matches all', () {
      expect(
        PluginStreamLanguages.pluginMatches(
          plugin([const PluginLanguage(kind: 'sub', code: 'fr')]),
          {},
        ),
        isTrue,
      );
    });

    test('undeclared does not match when filter set', () {
      expect(
        PluginStreamLanguages.pluginMatches(plugin(const []), {'sub:fr'}),
        isFalse,
      );
    });

    test('declared must intersect', () {
      final fr = plugin(const [
        PluginLanguage(kind: 'sub', code: 'fr'),
        PluginLanguage(kind: 'dub', code: 'fr'),
      ]);
      expect(PluginStreamLanguages.pluginMatches(fr, {'sub:fr'}), isTrue);
      expect(PluginStreamLanguages.pluginMatches(fr, {'dub:en'}), isFalse);
    });
  });

  group('PluginStreamLanguages.unionFromPacks', () {
    test('unions movie/tv languages', () {
      final packs = [
        EnginePack(
          sourceUrl: 'https://example.test/manifest.json',
          packId: 'test-pack',
          name: 'Test',
          version: '1',
          plugins: [
            EnginePlugin(
              id: 'test-provider-fr',
              name: 'FR',
              entry: 'fr.js',
              types: const ['movie', 'tv'],
              languages: const [
                PluginLanguage(kind: 'sub', code: 'fr'),
                PluginLanguage(kind: 'dub', code: 'fr'),
              ],
            ),
            EnginePlugin(
              id: 'test-provider-en',
              name: 'EN',
              entry: 'en.js',
              types: const ['movie', 'tv'],
              languages: const [
                PluginLanguage(kind: 'sub', code: 'en'),
                PluginLanguage(kind: 'dub', code: 'en'),
              ],
            ),
            EnginePlugin(
              id: 'test-provider-anime',
              name: 'Anime',
              entry: 'a.js',
              types: const ['anime'],
              languages: const [
                PluginLanguage(kind: 'sub', code: 'ja'),
              ],
            ),
          ],
        ),
      ];
      final union = PluginStreamLanguages.unionFromPacks(
        packs: packs,
        types: const ['movie'],
      );
      expect(union.map((e) => e.key).toList(), [
        'sub:en',
        'sub:fr',
        'dub:en',
        'dub:fr',
      ]);
    });

    test('kinds filter keeps only matching language kinds', () {
      final packs = [
        EnginePack(
          sourceUrl: 'https://example.test/manifest.json',
          packId: 'test-pack',
          name: 'Test',
          version: '1',
          plugins: [
            EnginePlugin(
              id: 'test-provider-anime',
              name: 'Anime',
              entry: 'a.js',
              types: const ['anime'],
              languages: const [
                PluginLanguage(kind: 'sub', code: 'en'),
                PluginLanguage(kind: 'dub', code: 'en'),
                PluginLanguage(kind: 'dub', code: 'fr'),
              ],
            ),
          ],
        ),
      ];
      final union = PluginStreamLanguages.unionFromPacks(
        packs: packs,
        types: const ['anime'],
        kinds: const ['dub'],
      );
      expect(union.map((e) => e.key).toList(), ['dub:en', 'dub:fr']);
    });

    test('en (VOST/VO) sorts before other codes in kind', () {
      final packs = [
        EnginePack(
          sourceUrl: 'https://example.test/manifest.json',
          packId: 'test-pack',
          name: 'Test',
          version: '1',
          plugins: [
            EnginePlugin(
              id: 'test-provider-ar',
              name: 'AR',
              entry: 'ar.js',
              types: const ['movie'],
              languages: const [
                PluginLanguage(kind: 'dub', code: 'ar'),
                PluginLanguage(kind: 'sub', code: 'ar'),
              ],
            ),
            EnginePlugin(
              id: 'test-provider-en',
              name: 'EN',
              entry: 'en.js',
              types: const ['movie'],
              languages: const [
                PluginLanguage(kind: 'sub', code: 'en'),
                PluginLanguage(kind: 'dub', code: 'en'),
              ],
            ),
          ],
        ),
      ];
      final union = PluginStreamLanguages.unionFromPacks(
        packs: packs,
        types: const ['movie'],
      );
      expect(union.map((e) => e.key).toList(), [
        'sub:en',
        'sub:ar',
        'dub:en',
        'dub:ar',
      ]);
    });
  });
}
