import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/playback/sources/stream_orchestrator.dart';

void main() {
  test('second caller joins the in-flight extract', () async {
    final orch = StreamOrchestrator.instance;
    var started = 0;
    final first = orch.schedule(
      sessionKey: 'title-a',
      pluginId: 'plugin-a',
      job: () async {
        started++;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return const EngineExtractResult(
          pluginId: 'plugin-a',
          pluginName: 'A',
          streams: [],
        );
      },
    );
    final second = orch.schedule(
      sessionKey: 'title-a',
      pluginId: 'plugin-a',
      job: () async {
        started++;
        return null;
      },
    );
    final a = await first;
    final b = await second;
    expect(started, 1);
    expect(identical(a, b), isTrue);
  });

  test('different plugins run at the same time', () async {
    final orch = StreamOrchestrator.instance;
    var inFlight = 0;
    var peak = 0;
    Future<void> one(String id) {
      return orch.schedule(
        sessionKey: 'title-b',
        pluginId: id,
        job: () async {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          inFlight--;
          return null;
        },
      );
    }

    await Future.wait([one('a'), one('b'), one('c')]);
    expect(peak, 3);
  });
}
