import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

void main() {
  setUp(() {
    ProviderScoreProbeSync.resetForTest();
    ProviderScoreMemory.resetForTest();
  });

  group('ProviderScoreProbeSync', () {
    final scope = ProviderScoreScope.movie(tmdbId: 99);

    test('providers with sources score +2 even if probe still trying', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vixsrc',
        status: StreamProviderProbeStatus.trying,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vixsrc'), 2);
      expect(ProviderScoreMemory.lastDeltaFor(scope, 'vixsrc'), 2);
    });

    test('failed probe with sources reconciles to server up', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vidrock',
        status: StreamProviderProbeStatus.failed,
        hasSources: false,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 0);

      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vidrock',
        status: StreamProviderProbeStatus.failed,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 2);
      expect(ProviderScoreMemory.lastDeltaFor(scope, 'vidrock'), 2);
    });

    test('syncSourcesCache marks every cached provider up', () async {
      await ProviderScoreProbeSync.syncSourcesCache(
        scope: scope,
        sourcesByProvider: {
          '111477': [
            StreamSource(url: 'http://x', title: 'a', type: 'mp4'),
          ],
          'empty': const [],
        },
      );
      expect(ProviderScoreMemory.scoreFor(scope, '111477'), 2);
      expect(ProviderScoreMemory.scoreFor(scope, 'empty'), 0);
    });
  });
}
