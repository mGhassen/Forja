import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import '../helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('cancel completes pending job with cancelled error', () async {
    final fut = EngineJobs.run(
      EngineAsyncJob.searchTorrents,
      {'query': 'test query that should cancel quickly'},
    );
    RustLib.instance.engineCancelPending();
    final raw = await fut.timeout(const Duration(seconds: 10));
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], 'cancelled');
  });

  test('EngineJobs runs search torrents job off main isolate', () async {
    final raw = await EngineJobs.run(
      EngineAsyncJob.searchTorrents,
      {'query': '{"query":"ubuntu","providers":["tpb"]}'},
    );
    final decoded = jsonDecode(raw);
    expect(decoded, isA<List>());
  });
}
