import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/playback/stream_open_pipeline.dart';

void main() {
  setUp(() {
    ProviderRuntimeConfig.instance.debugSetSnapshot(
      ProviderRuntimeSnapshot.builtins(),
    );
  });

  group('StreamOpenPipeline', () {
    test('returns direct open once then exhausts', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
      );

      final step = await pipe.next();
      expect(step?.action, StreamOpenAction.openDirect);
      expect(step?.playUrl, 'https://cdn.example/x/master.m3u8');
      expect(step?.catalogUrl, 'https://cdn.example/x/master.m3u8');
      expect(step?.reason, 'direct');

      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

    test('progressive mp4 → direct only', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/video.mp4',
        providerId: 'megaplay',
      );
      expect((await pipe.next())?.action, StreamOpenAction.openDirect);
      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

    test('normalizes catalog url before open', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://vixsrc.to/playlist/174559?b=1&token=abc',
        providerId: 'engine:vixsrc',
      );
      final step = await pipe.next();
      expect(step?.action, StreamOpenAction.openDirect);
      expect(step?.playUrl, contains('vixsrc.to'));
      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });
  });
}
