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
    test('auto excludes cross-domain providers', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.anime,
        candidateIds: ['videasy', 'megaplay', 'kisskh', 'vidlink'],
      );
      expect(ordered, contains('megaplay'));
      expect(ordered, contains('vidlink')); // dual-domain: movies/series + anime
      expect(ordered, isNot(contains('kisskh')));
      expect(ordered, isNot(contains('videasy')));
      expect(ordered.first, 'megaplay');
    });

    test('settings baseline with bounded domain adjustment for movies', () {
      final result = SourceEngine.orderProviders(
        domain: SourceDomain.movies,
        candidateIds: ['vidsrc', 'vixsrc'],
        settingsOrder: ['vidsrc', 'vixsrc'],
      );
      final vidsrc = result.rows.firstWhere((r) => r.id == 'vidsrc');
      final vixsrc = result.rows.firstWhere((r) => r.id == 'vixsrc');
      expect(vidsrc.settingsRank, 0);
      expect(vixsrc.settingsRank, 1);
      expect(vixsrc.domainScore, greaterThan(vidsrc.domainScore));
      expect(
        (vixsrc.effectiveRank - vidsrc.effectiveRank).abs(),
        lessThanOrEqualTo(2),
      );
    });

    test('series prefers vidlink domain score within bounded window', () {
      final result = SourceEngine.orderProviders(
        domain: SourceDomain.series,
        candidateIds: ['videasy', 'vidlink'],
        settingsOrder: ['videasy', 'vidlink'],
      );
      final videasy = result.rows.firstWhere((r) => r.id == 'videasy');
      final vidlink = result.rows.firstWhere((r) => r.id == 'vidlink');
      expect(vidlink.domainScore, greaterThan(videasy.domainScore));
      expect(vidlink.effectiveRank, lessThanOrEqualTo(videasy.effectiveRank + 2));
    });

    test('preferred pin is strict', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['videasy', 'vidlink', 'webstreamr'],
        preferred: 'webstreamr',
      );
      expect(ordered, ['webstreamr']);
    });

    test('preferred pin rejects unsupported domain', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.anime,
        candidateIds: ['videasy', 'megaplay'],
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
      expect(result.rows.single.domainScore, greaterThan(0));
      expect(result.rows.single.maxDisplacement, maxProviderDisplacement);
    });
  });
}
