import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/screens/playback_failover_gate.dart';

void main() {
  group('canAutoHopAfterSourcesExhausted', () {
    test('prevalidated green Play list + host reload hook → hop allowed', () {
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: false,
          streamsPrevalidated: true,
          hasMovie: true,
          hasProviders: false,
          hostOwnsReload: true,
        ),
        isTrue,
      );
    });

    test('prevalidated without a reload hook or providers → no hop', () {
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: false,
          streamsPrevalidated: true,
          hasMovie: true,
          hasProviders: true,
          hostOwnsReload: false,
        ),
        isFalse,
      );
    });

    test('pinned server or source never hops', () {
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: true,
          streamsPrevalidated: false,
          hasMovie: true,
          hasProviders: true,
          hostOwnsReload: true,
        ),
        isFalse,
      );
    });

    test('no movie context → no hop', () {
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: false,
          streamsPrevalidated: false,
          hasMovie: false,
          hasProviders: true,
          hostOwnsReload: true,
        ),
        isFalse,
      );
    });

    test('unvalidated list hops with providers or a reload hook', () {
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: false,
          streamsPrevalidated: false,
          hasMovie: true,
          hasProviders: true,
          hostOwnsReload: false,
        ),
        isTrue,
      );
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: false,
          streamsPrevalidated: false,
          hasMovie: true,
          hasProviders: false,
          hostOwnsReload: true,
        ),
        isTrue,
      );
      expect(
        canAutoHopAfterSourcesExhausted(
          pinned: false,
          streamsPrevalidated: false,
          hasMovie: true,
          hasProviders: false,
          hostOwnsReload: false,
        ),
        isFalse,
      );
    });
  });
}
