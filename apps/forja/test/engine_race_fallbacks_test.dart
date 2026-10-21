import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/open/engine_race_fallbacks.dart';
import 'package:rust/rust.dart';

StreamSource _src(String url, {String title = 'row'}) =>
    StreamSource(url: url, title: title, type: 'hls');

void main() {
  group('EngineRaceFallbacks window', () {
    test(
      'closes after extraWins verified rows and reports via onClose',
      () async {
        var closed = 0;
        final fb = EngineRaceFallbacks(
          winner: [_src('https://a/w.m3u8')],
          window: const Duration(seconds: 30),
          extraWins: 2,
          onClose: () => closed++,
        );
        expect(fb.isClosed, isFalse);
        fb.addVerified([_src('https://b/1.m3u8')]);
        expect(fb.isClosed, isFalse);
        fb.addVerified([_src('https://c/2.m3u8')]);
        expect(fb.isClosed, isTrue);
        expect(closed, 1);
        await fb.closed;
        expect(fb.verifiedCount, 2);
      },
    );

    test('closes on the window timeout with no extra wins', () async {
      var closed = 0;
      final fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(milliseconds: 30),
        extraWins: 2,
        onClose: () => closed++,
      );
      await fb.closed.timeout(const Duration(seconds: 2));
      expect(fb.isClosed, isTrue);
      expect(closed, 1);
      expect(fb.verifiedCount, 0);
    });

    test('close() is idempotent and ignores rows after close', () {
      var closed = 0;
      final fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(seconds: 30),
        onClose: () => closed++,
      );
      fb.close();
      fb.close();
      fb.addVerified([_src('https://b/1.m3u8')]);
      expect(closed, 1);
      expect(fb.verifiedCount, 0);
    });

    test(
      'winner stays excluded; losers keep probe order; duplicates drop',
      () async {
        final fb = EngineRaceFallbacks(
          winner: [_src('https://a/w.m3u8')],
          window: const Duration(seconds: 30),
          extraWins: 5,
        );
        fb.addVerified([_src('https://b/1.m3u8')]);
        fb.addVerified([_src('https://a/w.m3u8')]); // winner again
        fb.addVerified([_src('https://c/2.m3u8'), _src('https://b/1.m3u8')]);
        fb.close();
        final out = await fb.drain();
        expect(out.map((s) => s.url), ['https://b/1.m3u8', 'https://c/2.m3u8']);
      },
    );

    test(
      'drain waits for close, hands each row out once, skips failed',
      () async {
        final fb = EngineRaceFallbacks(
          winner: [_src('https://a/w.m3u8')],
          window: const Duration(seconds: 30),
          extraWins: 5,
        );
        fb.addVerified([_src('https://b/1.m3u8'), _src('https://c/2.m3u8')]);
        var drained = false;
        final pending = fb.drain(exclude: ['https://b/1.m3u8']).then((rows) {
          drained = true;
          return rows;
        });
        await Future<void>.delayed(Duration.zero);
        expect(drained, isFalse, reason: 'drain must wait for the window');
        fb.close();
        final first = await pending;
        expect(first.map((s) => s.url), ['https://c/2.m3u8']);
        final second = await fb.drain();
        expect(second, isEmpty, reason: 'rows are handed out once');
      },
    );

    test('unprobed rows are capped and ordered behind verified rows', () async {
      final fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(seconds: 30),
        extraWins: 5,
      );
      fb.addVerified([_src('https://b/1.m3u8')]);
      fb.addUnprobedRows([
        {'url': 'https://a/w.m3u8'}, // winner
        {'url': 'https://b/1.m3u8'}, // already verified
        {'url': 'https://d/3.m3u8'},
        {'url': ''},
        {'url': 'https://e/4.m3u8'},
        {'url': 'https://f/5.m3u8'},
      ], max: 2);
      fb.close();
      expect(fb.unprobedRows.map((r) => r['url']), [
        'https://d/3.m3u8',
        'https://e/4.m3u8',
      ]);
      final verified = await fb.drain();
      expect(verified.map((s) => s.url), ['https://b/1.m3u8']);
      final raw = fb.takeUnprobedRows(exclude: ['https://e/4.m3u8']);
      expect(raw.map((r) => r['url']), ['https://d/3.m3u8']);
      expect(fb.takeUnprobedRows(), isEmpty);
    });
  });

  group('drainFallbacksThenReload', () {
    test('no window → reload at once', () async {
      var reloads = 0;
      final out = await drainFallbacksThenReload(
        fallbacks: null,
        reload: () async {
          reloads++;
          return [_src('https://r/1.m3u8')];
        },
      );
      expect(reloads, 1);
      expect(out?.single.url, 'https://r/1.m3u8');
    });

    test(
      'verified backups first, unprobed behind, reload not called',
      () async {
        final fb = EngineRaceFallbacks(
          winner: [_src('https://a/w.m3u8')],
          window: const Duration(seconds: 30),
          extraWins: 5,
        );
        fb.addVerified([_src('https://b/1.m3u8')]);
        fb.addUnprobedRows([
          {'url': 'https://d/3.m3u8'},
        ]);
        fb.close();
        var reloads = 0;
        final out = await drainFallbacksThenReload(
          fallbacks: fb,
          failedUrls: ['https://a/w.m3u8'],
          convertUnprobed: (rows) async => [
            for (final r in rows) _src(r['url'] as String, title: 'unprobed'),
          ],
          reload: () async {
            reloads++;
            return [_src('https://r/1.m3u8')];
          },
        );
        expect(reloads, 0);
        expect(out?.map((s) => s.url), [
          'https://b/1.m3u8',
          'https://d/3.m3u8',
        ]);
      },
    );

    test('backups exhausted → falls through to reload', () async {
      final fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(seconds: 30),
        extraWins: 5,
      );
      fb.addVerified([_src('https://b/1.m3u8')]);
      fb.close();
      await fb.drain();
      var reloads = 0;
      final out = await drainFallbacksThenReload(
        fallbacks: fb,
        reload: () async {
          reloads++;
          return [_src('https://r/1.m3u8')];
        },
      );
      expect(reloads, 1);
      expect(out?.single.url, 'https://r/1.m3u8');
    });

    test('all backups already failed → reload', () async {
      final fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(seconds: 30),
        extraWins: 5,
      );
      fb.addVerified([_src('https://b/1.m3u8')]);
      fb.close();
      var reloads = 0;
      await drainFallbacksThenReload(
        fallbacks: fb,
        failedUrls: ['https://b/1.m3u8'],
        reload: () async {
          reloads++;
          return null;
        },
      );
      expect(reloads, 1);
    });
  });

  group('reloadBatchHasUntriedUrl', () {
    test('empty batch is not worth opening', () {
      expect(
        reloadBatchHasUntriedUrl(batch: const [], triedUrls: {'x'}),
        isFalse,
      );
    });

    test('batch of already-tried URLs ends the chain', () {
      expect(
        reloadBatchHasUntriedUrl(
          batch: [_src('https://a/w.m3u8')],
          triedUrls: {'https://a/w.m3u8'},
        ),
        isFalse,
      );
    });

    test('one new URL is enough', () {
      expect(
        reloadBatchHasUntriedUrl(
          batch: [_src('https://a/w.m3u8'), _src('https://b/1.m3u8')],
          triedUrls: {'https://a/w.m3u8'},
        ),
        isTrue,
      );
    });
  });

  group('review fixes', () {
    test('pool admits no new plugin once a winner is chosen', () {
      expect(
        engineRacePoolAdmits(winnerChosen: false, closed: false),
        isTrue,
      );
      expect(
        engineRacePoolAdmits(winnerChosen: true, closed: false),
        isFalse,
        reason: 'in-flight workers continue; no new admission after the win',
      );
      expect(engineRacePoolAdmits(winnerChosen: true, closed: true), isFalse);
      expect(
        engineRacePoolAdmits(winnerChosen: false, closed: true),
        isFalse,
      );
    });

    test('timer close runs the hook first so parked unprobed rows are drained',
        () async {
      late EngineRaceFallbacks fb;
      fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(milliseconds: 30),
        extraWins: 5,
        onClose: () {
          expect(fb.isClosed, isTrue);
          fb.addUnprobedRows([
            {'url': 'https://u/1.m3u8'},
          ]);
          // Verified rows are no longer accepted inside the close hook.
          fb.addVerified([_src('https://late/x.m3u8')]);
        },
      );
      final drained = fb.drain();
      final raw = await drained.then((_) => fb.takeUnprobedRows());
      expect(fb.verifiedCount, 0);
      expect(raw.map((r) => r['url']), ['https://u/1.m3u8']);
    });

    test('extra-wins close also runs the hook before closed completes',
        () async {
      var hookRan = false;
      late EngineRaceFallbacks fb;
      fb = EngineRaceFallbacks(
        winner: [_src('https://a/w.m3u8')],
        window: const Duration(seconds: 30),
        extraWins: 1,
        onClose: () {
          hookRan = true;
          fb.addUnprobedRows([
            {'url': 'https://u/2.m3u8'},
          ]);
        },
      );
      final waiter = fb.closed.then((_) => fb.unprobedRows.length);
      fb.addVerified([_src('https://b/1.m3u8')]);
      expect(hookRan, isTrue);
      expect(await waiter, 1);
    });

    test('rows whose URL already failed in a player are skipped', () {
      final failed = {'https://dead/1.m3u8', 'https://cat/dead.m3u8'};
      expect(streamRowUrlFailed({'url': 'https://dead/1.m3u8'}, failed), isTrue);
      expect(streamRowUrlFailed({'url': 'https://ok/1.m3u8'}, failed), isFalse);
      expect(streamRowUrlFailed({'url': ''}, failed), isFalse);
      final kept = dropFailedStreamSources(
        [
          _src('https://dead/1.m3u8'),
          StreamSource(
            url: 'http://127.0.0.1:9/hls-proxy?x',
            title: 'proxied',
            type: 'hls',
            catalogUrl: 'https://cat/dead.m3u8',
          ),
          _src('https://ok/1.m3u8'),
        ],
        failed,
      );
      expect(kept.map((s) => s.url), ['https://ok/1.m3u8']);
      final untouched = [_src('https://ok/1.m3u8')];
      expect(
        identical(dropFailedStreamSources(untouched, const []), untouched),
        isTrue,
      );
    });

    test('reload returns the new winner, then verified backups, then unprobed',
        () async {
      final fb = EngineRaceFallbacks(
        winner: [_src('https://w/1.m3u8')],
        window: const Duration(seconds: 30),
        extraWins: 5,
      );
      fb.addVerified([_src('https://b/1.m3u8'), _src('https://dead/2.m3u8')]);
      fb.addUnprobedRows([
        {'url': 'https://u/3.m3u8'},
        {'url': 'https://b/1.m3u8'}, // already verified → dropped
      ]);
      fb.close();
      final out = await reloadSourcesWithFallbacks(
        sources: [_src('https://w/1.m3u8')],
        fallbacks: fb,
        failedUrls: ['https://dead/2.m3u8'],
        convertUnprobed: (rows) async => [
          for (final r in rows) _src(r['url'] as String),
        ],
      );
      expect(out.map((s) => s.url), [
        'https://w/1.m3u8',
        'https://b/1.m3u8',
        'https://u/3.m3u8',
      ]);
    });

    test('reload without a window returns the sources unchanged', () async {
      final out = await reloadSourcesWithFallbacks(
        sources: [_src('https://w/1.m3u8')],
        fallbacks: null,
      );
      expect(out.map((s) => s.url), ['https://w/1.m3u8']);
    });
  });

  test('policy values are the documented defaults', () {
    expect(EngineRaceFallbackPolicy.window, const Duration(milliseconds: 800));
    expect(EngineRaceFallbackPolicy.extraWins, 2);
    expect(EngineRaceFallbackPolicy.maxUnprobedRows, 4);
    expect(EngineRaceFallbackPolicy.reloadPasses, 2);
  });
}
