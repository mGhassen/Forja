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

    test('trying with sources does not score', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vixsrc',
        status: StreamProviderProbeStatus.trying,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vixsrc'), 0);
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'vixsrc'), isNull);
    });

    test('extract success alone does not apply server +2', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vixsrc',
        status: StreamProviderProbeStatus.success,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vixsrc'), 0);
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'vixsrc'), isNull);
    });

    test('streamsResolved success commits linked +2+2', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'animehost',
        status: StreamProviderProbeStatus.success,
        hasSources: true,
        streamsResolved: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'animehost'), 4);
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'animehost'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(scope, 'animehost'), 2);
    });

    test('CDN dead after extract commits linked +2−2', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'animedao',
        status: StreamProviderProbeStatus.success,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'animedao'), 0);
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'animedao',
        status: StreamProviderProbeStatus.failed,
        hasSources: true,
        streamsResolved: true,
      );
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'animedao'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(scope, 'animedao'), -2);
      expect(ProviderScoreMemory.scoreFor(scope, 'animedao'), 0);
    });

    test('success without sources applies −2', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'empty',
        status: StreamProviderProbeStatus.success,
        hasSources: false,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'empty'), -2);
    });

    test('failed without sources applies −2', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vidrock',
        status: StreamProviderProbeStatus.failed,
        hasSources: false,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), -2);
    });

    test('failed with sources (abandoned check) does not score', () async {
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vidrock',
        status: StreamProviderProbeStatus.trying,
        hasSources: true,
      );
      await ProviderScoreProbeSync.onProbeStatusChanged(
        scope: scope,
        providerId: 'vidrock',
        status: StreamProviderProbeStatus.failed,
        hasSources: true,
      );
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 0);
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'vidrock'), isNull);
    });

    test('syncSourcesCache extract-only does not score', () async {
      await ProviderScoreProbeSync.syncSourcesCache(
        scope: scope,
        sourcesByProvider: {
          '111477': [
            StreamSource(url: 'http://x', title: 'a', type: 'mp4'),
          ],
        },
      );
      expect(ProviderScoreMemory.scoreFor(scope, '111477'), 0);
    });
  });

  group('ProviderScoreMemory linked server+stream', () {
    final scope = ProviderScoreScope.movie(tmdbId: 7);

    test('linked streams down is +2−2 net 0', () async {
      await ProviderScoreMemory.recordLinkedStreamsDown(scope, 'anikoto');
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'anikoto'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(scope, 'anikoto'), -2);
      expect(ProviderScoreMemory.scoreFor(scope, 'anikoto'), 0);
      expect(ProviderScoreMemory.globalScoreFor('anikoto'), 0);
    });

    test('linked streams up is +2+2 net 4', () async {
      await ProviderScoreMemory.recordLinkedStreamsUp(scope, 'vixsrc');
      expect(ProviderScoreMemory.scoreFor(scope, 'vixsrc'), 4);
      expect(ProviderScoreMemory.globalScoreFor('vixsrc'), 4);
    });

    test('all streams down commits linked +2−2', () async {
      final applied = await ProviderScoreMemory.recordAllStreamsDownIfNeeded(
        scope: scope,
        providerId: 'vidrock',
        streamUrls: const ['a', 'b'],
        isStreamFailed: (_) => true,
      );
      expect(applied, isTrue);
      expect(ProviderScoreMemory.serverVerdictFor(scope, 'vidrock'), 2);
      expect(ProviderScoreMemory.streamVerdictFor(scope, 'vidrock'), -2);
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 0);
    });

    test('up server + all streams dead nets 0', () async {
      await ProviderScoreMemory.recordServerUp(scope, 'vidrock');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 2);
      await ProviderScoreMemory.recordStreamFail(scope, 'vidrock');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidrock'), 0);
      expect(ProviderScoreMemory.lastDeltaFor(scope, 'vidrock'), -2);
    });

    test('a proven working stream is sticky over later dead reports', () async {
      await ProviderScoreMemory.recordLinkedStreamsUp(scope, 'vidnest');
      await ProviderScoreMemory.recordStreamFail(scope, 'vidnest');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidnest'), 4);
    });

    test('server that never resolved keeps title net negative', () async {
      await ProviderScoreMemory.recordServerFailure(scope, 'vidzee');
      expect(ProviderScoreMemory.scoreFor(scope, 'vidzee'), -2);
      expect(ProviderScoreMemory.globalScoreFor('vidzee'), 0);
    });

    test('stream fail before server up leaves global Σ at 0', () async {
      await ProviderScoreMemory.recordStreamFail(scope, 'anikoto');
      await ProviderScoreMemory.recordServerUp(scope, 'anikoto');
      expect(ProviderScoreMemory.scoreFor(scope, 'anikoto'), 0);
      expect(ProviderScoreMemory.globalScoreFor('anikoto'), 0);
    });
  });
}
