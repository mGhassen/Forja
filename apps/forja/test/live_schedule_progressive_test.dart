import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/live_schedule_progressive.dart';
import 'package:forja_foundation/protocol/protocol.dart';

EnginePlugin _catalog(String id) =>
    EnginePlugin.fromJson({'id': id, 'name': 'Catalog $id'});

Map<String, dynamic> _row(String id) => {'id': id, 'label': 'row $id'};

/// Reduce stand-in: the real pack filters/shapes; here items == rows.
Future<MetaEnvelope> _reduce(List<Map<String, dynamic>> rows) async =>
    MetaEnvelope(ok: true, action: 'feed', data: {'items': rows});

int _count(MetaEnvelope env) => (env.data?['items'] as List).length;

void main() {
  setUp(EngineCache.instance.wipeAll);

  group('fanOutLiveScheduleCatalogs', () {
    test(
      'holds empty envelopes while catalogs remain and later ones have rows',
      () async {
        final events = <String>[];
        final catalogs = [_catalog('t-a'), _catalog('t-b'), _catalog('t-c')];
        final rows = {
          't-a': <Map<String, dynamic>>[],
          't-b': <Map<String, dynamic>>[],
          't-c': [_row('m1')],
        };

        final out = <MetaEnvelope>[];
        await for (final env in fanOutLiveScheduleCatalogs(
          catalogs: catalogs,
          aggregateKey: 'raw:test-all',
          forceRefresh: false,
          setBusy: ({required busy, label}) => events.add('busy:$busy'),
          runCatalog: (p) async {
            events.add('scrape:${p.id}');
            return rows[p.id]!;
          },
          reduce: (r) async {
            final env = await _reduce(r);
            events.add('reduce:${_count(env)}');
            return env;
          },
        )) {
          events.add('yield:${_count(env)}');
          out.add(env);
        }

        // Every reduce ran, but only the final non-empty one reached the painter.
        expect(events.where((e) => e.startsWith('reduce:')).length, 3);
        expect(out.length, 1);
        expect(_count(out.single), 1);
        expect(events.where((e) => e.startsWith('yield:0')), isEmpty);
        expect(events.last, 'yield:1');
        expect(events[events.length - 2], 'busy:false');
      },
    );

    test('paints as soon as the first catalog has rows (issue 278)', () async {
      final events = <String>[];
      final catalogs = [_catalog('t-a'), _catalog('t-b'), _catalog('t-c')];
      final rows = {
        't-a': [_row('m1')],
        't-b': <Map<String, dynamic>>[],
        't-c': [_row('m2')],
      };

      final counts = <int>[];
      await for (final env in fanOutLiveScheduleCatalogs(
        catalogs: catalogs,
        aggregateKey: 'raw:test-all',
        forceRefresh: false,
        setBusy: ({required busy, label}) {},
        runCatalog: (p) async {
          events.add('scrape:${p.id}');
          return rows[p.id]!;
        },
        reduce: _reduce,
      )) {
        events.add('yield:${_count(env)}');
        counts.add(_count(env));
      }

      // First envelope arrives before the second catalog is scraped.
      expect(events.indexOf('yield:1'), lessThan(events.indexOf('scrape:t-b')));
      // Empty second catalog still yields (rows already present) — never 0.
      expect(counts, [1, 1, 2]);
    });

    test(
      'yields one final empty envelope when every catalog is empty',
      () async {
        final busyStates = <bool>[];
        final labels = <String?>[];
        final catalogs = [_catalog('t-a'), _catalog('t-b')];

        final out = <MetaEnvelope>[];
        await for (final env in fanOutLiveScheduleCatalogs(
          catalogs: catalogs,
          aggregateKey: 'raw:test-all',
          forceRefresh: false,
          setBusy: ({required busy, label}) {
            busyStates.add(busy);
            labels.add(label);
          },
          runCatalog: (_) async => const [],
          reduce: _reduce,
        )) {
          out.add(env);
        }

        expect(out.length, 1);
        expect(_count(out.single), 0);
        expect(busyStates.last, isFalse);
        expect(labels.first, 'Loading Catalog t-a… 1/2');
        expect(labels[1], 'Loading Catalog t-b… 2/2');
      },
    );

    test('cancel mid-scrape stops remaining catalogs and busy writes', () async {
      final events = <String>[];
      var cancelled = false;
      final catalogs = [_catalog('t-a'), _catalog('t-b'), _catalog('t-c')];
      final gateB = Completer<List<Map<String, dynamic>>>();
      final scrapingB = Completer<void>();

      final stream = fanOutLiveScheduleCatalogs(
        catalogs: catalogs,
        aggregateKey: 'raw:test-all',
        forceRefresh: false,
        isCancelled: () => cancelled,
        setBusy: ({required busy, label}) => events.add('busy:$busy'),
        runCatalog: (p) async {
          events.add('scrape:${p.id}');
          if (p.id == 't-a') return const [];
          if (p.id == 't-b') {
            scrapingB.complete();
            return gateB.future;
          }
          return [_row('m2')];
        },
        reduce: (r) async {
          events.add('reduce:${r.length}');
          return _reduce(r);
        },
      );
      final sub = stream.listen((env) => events.add('yield:${_count(env)}'));

      // Catalog A was empty (held, no yield); generator is parked on B.
      await scrapingB.future;
      expect(events, [
        'busy:true',
        'scrape:t-a',
        'reduce:0',
        'busy:true',
        'scrape:t-b',
      ]);

      // Painter cancels while B is still in flight; B answers afterwards.
      cancelled = true;
      final cancelDone = sub.cancel();
      final before = events.length;
      gateB.complete([_row('m1')]);
      // Completes only when the generator body exits — proves the cancelled
      // path leaves the loop instead of running to the next yield.
      await cancelDone;

      // Nothing after the cancel: no reduce of B, no scrape of C, no busy write.
      expect(events.sublist(before), isEmpty);
      expect(events.where((e) => e == 'scrape:t-c'), isEmpty);
    });

    test(
      'a failing catalog does not surface an empty envelope early',
      () async {
        final catalogs = [_catalog('t-a'), _catalog('t-b')];
        final out = <MetaEnvelope>[];
        await for (final env in fanOutLiveScheduleCatalogs(
          catalogs: catalogs,
          aggregateKey: 'raw:test-all',
          forceRefresh: true,
          setBusy: ({required busy, label}) {},
          runCatalog: (p) async {
            if (p.id == 't-a') throw StateError('upstream down');
            return [_row('m1')];
          },
          reduce: _reduce,
        )) {
          out.add(env);
        }
        expect(out.map(_count).toList(), [1]);
      },
    );
  });
}
