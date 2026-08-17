import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:rust/rust.dart';
import 'helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForAppTests();
  });

  group('DomainPlaybackResolve failover', () {
    test('single kisskh mirror has empty failover chain', () {
      final chain = DomainPlaybackResolve.failoverChain(
        domain: SourceDomain.asianDrama,
        providers: {'kisskh.co': {}},
        currentProviderId: 'kisskh.co',
        settingsOrder: const ['kisskh.co'],
      );
      expect(chain, isEmpty);
    });

    test('asian drama default enables kisskh.co', () {
      final order = SourceEngine.orderProviders(
        domain: SourceDomain.asianDrama,
        candidateIds: const [
          'kisskh.co',
          'kisskh.nl',
          'kisskh.ovh',
          'kisskh.la',
          'kisskh.do',
        ],
        settingsOrder: const ['kisskh.co'],
      );
      expect(SettingsService.defaultAsianDramaProviderOrder, [
        'kisskh.co',
        'kisskh.nl',
        'kisskh.ovh',
        'kisskh.la',
        'kisskh.do',
      ]);
      expect(order.orderedIds.first, 'kisskh.co');
      expect(order.rows.every((r) => r.supported), isTrue);
    });

    test('legacy kisskh id still orders for asian drama', () {
      final order = SourceEngine.orderProviders(
        domain: SourceDomain.asianDrama,
        candidateIds: ['kisskh'],
        settingsOrder: const ['kisskh'],
      );
      expect(order.orderedIds, ['kisskh']);
      expect(order.rows.single.supported, isTrue);
    });
  });
}
