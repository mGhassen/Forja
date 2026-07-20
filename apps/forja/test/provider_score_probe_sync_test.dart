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
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), -2);

      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vidrock',
        status: StreamProviderProbeStatus.failed,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 2);
      expect(ProviderScoreMemory.lastDeltaFor(scope, 'vidrock'), 4);
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

  group('ProviderScoreMemory netted verdicts', () {
    final scope = ProviderScoreScope.movie(tmdbId: 7);

    test('up server + all streams dead nets 0', () async {
      await ProviderScoreMemory.recordServerUp(scope, 'vidrock');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 2);
      await ProviderScoreMemory.recordStreamFail(scope, 'vidrock');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 0);
      expect(ProviderScoreMemory.lastDeltaFor(scope, 'vidrock'), -2);
    });

    test('up server + working stream nets 4', () async {
      await ProviderScoreMemory.recordServerUp(scope, 'vixsrc');
      await ProviderScoreMemory.recordStreamUp(scope, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(scope, 'vixsrc'), 4);
    });

    test('a proven working stream is sticky over later dead reports', () async {
      await ProviderScoreMemory.recordServerUp(scope, 'vidnest');
      await ProviderScoreMemory.recordStreamUp(scope, 'vidnest');
      await ProviderScoreMemory.recordStreamFail(scope, 'vidnest');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidnest'), 4);
    });

    test('server that never resolved keeps title net negative', () async {
      await ProviderScoreMemory.recordServerFailure(scope, 'vidzee');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidzee'), -2);
      expect(ProviderScoreMemory.lastDeltaFor(scope, 'vidzee'), -2);
      expect(ProviderScoreMemory.globalScoreFor('vidzee'), 0);
    });

    test('re-checking the same title does not drift', () async {
      for (var i = 0; i < 5; i++) {
        await ProviderScoreMemory.recordServerUp(scope, 'webstreamr');
        await ProviderScoreMemory.recordStreamFail(scope, 'webstreamr');
      }
      expect(ProviderScoreMemory.scoreFor(scope, 'webstreamr'), 0);
    });

    test('stream fail before server up leaves global Σ at 0', () async {
      await ProviderScoreMemory.recordStreamFail(scope, 'anikoto');
      await ProviderScoreMemory.recordServerUp(scope, 'anikoto');
      expect(ProviderScoreMemory.scoreFor(scope, 'anikoto'), 0);
      expect(ProviderScoreMemory.globalScoreFor('anikoto'), 0);
    });
  });
}
