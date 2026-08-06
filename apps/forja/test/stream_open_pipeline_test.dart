import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/playback/stream_media_classifier.dart';
import 'package:forja/shared/playback/stream_open_pipeline.dart';

void main() {
  setUp(() {
    ProviderRuntimeConfig.instance.debugSetSnapshot(
      ProviderRuntimeSnapshot.builtins(),
    );
  });

  group('StreamOpenPipeline', () {
    test('pngWrapTs → strip first; openFailed → direct', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        mediaClassOverride: StreamMediaClass.pngWrapTs,
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );

      final a = await pipe.next();
      expect(a?.action, StreamOpenAction.openPngStrip);
      expect(a?.playUrl, contains('strip=png'));

      pipe.report(StreamOpenStepResult.openFailed);
      final b = await pipe.next();
      expect(b?.action, StreamOpenAction.openDirect);

      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

    test('plainMedia → direct first; fail → strip', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        mediaClassOverride: StreamMediaClass.plainMedia,
        buildStripProxy: (u, _) => 'http://127.0.0.1:9/proxy?u=$u',
      );

      final a = await pipe.next();
      expect(a?.action, StreamOpenAction.openDirect);

      pipe.report(StreamOpenStepResult.decodeFailed);
      final b = await pipe.next();
      expect(b?.action, StreamOpenAction.openPngStrip);

      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

    test('imageNoTs exhausts without open', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        mediaClassOverride: StreamMediaClass.imageNoTs,
        buildStripProxy: (u, _) =>
            'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );
      expect(await pipe.next(), isNull);
    });

    test('httpBlocked exhausts without open', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        mediaClassOverride: StreamMediaClass.httpBlocked,
      );
      expect(await pipe.next(), isNull);
    });

    test('strip proxy unavailable → re-branch to direct for pngWrapTs',
        () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        mediaClassOverride: StreamMediaClass.pngWrapTs,
        buildStripProxy: (_, __) => '',
      );
      final a = await pipe.next();
      expect(a?.action, StreamOpenAction.openDirect);
      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

    test('progressive → direct only', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/video.mp4',
        providerId: 'megaplay',
        mediaClassOverride: StreamMediaClass.plainMedia,
      );
      expect((await pipe.next())?.action, StreamOpenAction.openDirect);
      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

    test('never profile → direct only', () async {
      final pipe = await StreamOpenPipeline.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'vidnest:animepahe',
        mediaClassOverride: StreamMediaClass.pngWrapTs,
      );
      expect((await pipe.next())?.action, StreamOpenAction.openDirect);
      pipe.report(StreamOpenStepResult.openFailed);
      expect(await pipe.next(), isNull);
    });

  });
}
