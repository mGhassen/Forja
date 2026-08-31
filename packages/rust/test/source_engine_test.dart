import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    if (!RustLib.isInitialized) {
      await RustLib.init(libraryPath: resolveRustLibPath());
    }
  });

  group('SourceEngine', () {
    test('settings order keeps all candidates including plugins', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['videasy', 'engine-plugin-x', 'vidlink'],
        settingsOrder: ['engine-plugin-x', 'vidlink'],
      );
      expect(ordered.first, 'engine-plugin-x');
      expect(ordered, contains('videasy'));
      expect(ordered, contains('vidlink'));
    });

    test('settings baseline ranks', () {
      final result = SourceEngine.orderProviders(
        domain: SourceDomain.movies,
        candidateIds: ['vidsrc', 'vixsrc'],
        settingsOrder: ['vidsrc', 'vixsrc'],
      );
      final vidsrc = result.rows.firstWhere((r) => r.id == 'vidsrc');
      final vixsrc = result.rows.firstWhere((r) => r.id == 'vixsrc');
      expect(vidsrc.settingsRank, 0);
      expect(vixsrc.settingsRank, 1);
      expect(vidsrc.domainScore, 1);
      expect(vixsrc.domainScore, 1);
    });

    test('preferred pin is strict', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['videasy', 'vidlink', 'vidsrc'],
        preferred: 'vidsrc',
      );
      expect(ordered, ['vidsrc']);
    });

    test('preferred pin rejects missing candidate', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.anime,
        candidateIds: ['megaplay'],
        preferred: 'videasy',
      );
      expect(ordered, isEmpty);
    });

    test('single-source asian drama kisskh', () {
      final result = SourceEngine.orderProviders(
        domain: SourceDomain.asianDrama,
        candidateIds: ['kisskh'],
        settingsOrder: ['kisskh'],
        preferred: 'kisskh',
      );
      expect(result.orderedIds, ['kisskh']);
      expect(
        SourceEngine.nextProviderIds(
          domain: SourceDomain.asianDrama,
          candidateIds: ['kisskh'],
          currentId: 'kisskh',
        ),
        isEmpty,
      );
    });

    test('order preview rows expose score breakdown', () {
      final result = SourceEngine.orderProviders(
        domain: SourceDomain.anime,
        candidateIds: ['megaplay'],
        settingsOrder: ['megaplay'],
      );
      expect(result.rows.single.domainScore, 1);
      expect(result.rows.single.maxDisplacement, maxProviderDisplacement);
    });
  });
}
