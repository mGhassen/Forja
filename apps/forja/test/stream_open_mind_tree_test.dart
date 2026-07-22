import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/playback/stream_open_strategy.dart';

void main() {
  setUp(() {
    ProviderRuntimeConfig.instance.debugSetSnapshot(
      ProviderRuntimeSnapshot.builtins(),
    );
  });

  group('StreamOpenMindTree branches', () {
    test('pngShell → strip first; openFailed → direct', () async {
      final tree = await StreamOpenMindTree.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        sniffFacts: () async => {StreamOpenFact.pngShell},
        buildStripProxy: (u, _) => 'http://127.0.0.1:9/hls-proxy?url=$u&strip=png',
      );

      final a = await tree.next();
      expect(a?.action, StreamOpenAction.playPngStrip);
      expect(a?.playUrl, contains('strip=png'));

      tree.report(StreamOpenStepResult.openFailed);
      final b = await tree.next();
      expect(b?.action, StreamOpenAction.playDirect);

      tree.report(StreamOpenStepResult.openFailed);
      expect(await tree.next(), isNull);
    });

    test('plain HLS → direct first; openFailed → strip', () async {
      final tree = await StreamOpenMindTree.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'megaplay',
        sniffFacts: () async => {StreamOpenFact.plainMedia},
        buildStripProxy: (u, _) => 'http://127.0.0.1:9/proxy?u=$u',
      );

      final a = await tree.next();
      expect(a?.action, StreamOpenAction.playDirect);

      tree.report(StreamOpenStepResult.decodeFailed);
      final b = await tree.next();
      expect(b?.action, StreamOpenAction.playPngStrip);

      tree.report(StreamOpenStepResult.openFailed);
      expect(await tree.next(), isNull);
    });

    test('progressive → direct only', () async {
      final tree = await StreamOpenMindTree.start(
        catalogUrl: 'https://cdn.example/video.mp4',
        providerId: 'megaplay',
        sniffFacts: () async => {StreamOpenFact.pngShell},
      );

      final a = await tree.next();
      expect(a?.action, StreamOpenAction.playDirect);
      tree.report(StreamOpenStepResult.openFailed);
      expect(await tree.next(), isNull);
    });

    test('never profile → direct only even if PNG sniffed', () async {
      final tree = await StreamOpenMindTree.start(
        catalogUrl: 'https://cdn.example/x/master.m3u8',
        providerId: 'vidnest:animepahe', // never strip
        sniffFacts: () async => {StreamOpenFact.pngShell},
      );

      expect((await tree.next())?.action, StreamOpenAction.playDirect);
      tree.report(StreamOpenStepResult.openFailed);
      expect(await tree.next(), isNull);
    });
  });
}
