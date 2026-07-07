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
      EngineAsyncJob.webstreamrGetStreams,
      {
        'requestJson':
            '{"media_type":"movie","tmdb_id":550,"enabled_sources":["vidsrc","rgshows"]}',
      },
    );
    RustLib.instance.engineCancelPending();
    final raw = await fut.timeout(const Duration(seconds: 10));
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], 'cancelled');
  });

  test('EngineJobs runs webstreamr job off main isolate', () async {
    final raw = await EngineJobs.run(
      EngineAsyncJob.webstreamrGetStreams,
      {
        'requestJson':
            '{"media_type":"movie","tmdb_id":550,"enabled_sources":["vidsrc"]}',
      },
    );
    final decoded = jsonDecode(raw);
    expect(decoded, isA<List>());
  });
}
