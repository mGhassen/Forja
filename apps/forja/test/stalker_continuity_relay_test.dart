import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/player/live_sports/live_sports_continuity_proxy.dart';

void main() {
  group('iptvStalkerUsesContinuityRelay', () {
    test('Stalker progressive live uses the relay', () {
      expect(
        iptvStalkerUsesContinuityRelay(
          kind: PortalLiveSourceKind.iptvStalker,
          url: 'http://panel.example/play/live.php?stream=1&play_token=a',
        ),
        isTrue,
      );
    });

    test('Stalker HLS and Xtream stay direct', () {
      expect(
        iptvStalkerUsesContinuityRelay(
          kind: PortalLiveSourceKind.iptvStalker,
          url: 'http://panel.example/live/1/index.m3u8',
        ),
        isFalse,
      );
      expect(
        iptvStalkerUsesContinuityRelay(
          kind: PortalLiveSourceKind.iptvXtream,
          url: 'http://panel.example/live/u/p/1.ts',
        ),
        isFalse,
      );
    });
  });

  test('relay mints a fresh upstream link on every reconnect', () async {
    // Upstream closes each socket after one chunk, like a panel that drops
    // the TS connection. A spent token answers 403.
    final served = <String>[];
    final spent = <String>{};
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((req) async {
      final token = req.uri.queryParameters['play_token'] ?? '';
      served.add(token);
      if (spent.contains(token)) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }
      spent.add(token);
      req.response.add(Uint8List(188 * 64));
      await req.response.close();
    });
    String link(int n) =>
        'http://127.0.0.1:${upstream.port}/play/live.php?play_token=t$n';

    var minted = 0;
    final relay = LiveSportsContinuityProxy();
    final local = await relay.start(
      upstreamUrl: link(0),
      headers: const {},
      refreshUpstream: () async => link(++minted),
    );

    final client = HttpClient();
    final req = await client.getUrl(local);
    final res = await req.close();
    final sub = res.listen((_) {});
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (served.length < 3 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await sub.cancel();
    client.close(force: true);
    await relay.stop();
    await upstream.close(force: true);

    expect(served.length, greaterThanOrEqualTo(3));
    expect(served.take(3), ['t0', 't1', 't2']);
  });
}
