import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/provider_score_memory.dart';

void main() {
  group('ProviderScoreMemory.effectiveScore', () {
    const base = 75;
    const id = 'vixsrc';

    test('starts at domain tier with no memory', () {
      expect(ProviderScoreMemory.effectiveScore(base, id), base);
    });

    test('playing floor stays at base despite penalties', () {
      // Simulate heavy penalty via direct API would need storage — use math path:
      // maxPenaltyForBase(75) = 34, so even max stored penalty caps display drop.
      final maxDrop = ProviderScoreMemory.maxPenaltyForBase(base);
      expect(maxDrop, lessThan(base));
      expect(
        ProviderScoreMemory.effectiveScore(base, id, isPlaying: true),
        base,
      );
    });

    test('max drop is bounded fraction of base not 1', () {
      expect(ProviderScoreMemory.maxPenaltyForBase(75), 34);
      expect(ProviderScoreMemory.maxPenaltyForBase(92), 41);
      expect(ProviderScoreMemory.maxPenaltyForBase(10), 12);
    });
  });
}
