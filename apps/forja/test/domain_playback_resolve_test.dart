import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:rust/rust.dart';
import 'helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForAppTests();
  });

  group('DomainPlaybackResolve failover', () {
    test('single kisskh provider has empty failover chain', () {
      final chain = DomainPlaybackResolve.failoverChain(
        domain: SourceDomain.asianDrama,
        providers: {'kisskh': {}},
        currentProviderId: 'kisskh',
        settingsOrder: const ['kisskh'],
      );
      expect(chain, isEmpty);
    });

    test('asian drama strict order is kisskh only', () {
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
