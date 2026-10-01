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
      EngineAsyncJob.httpGet,
      {
        'url': 'http://127.0.0.1:1/',
        'timeout_secs': 60,
        'headers_json': '{}',
      },
    );
    RustLib.instance.engineCancelPending();
    final raw = await fut.timeout(const Duration(seconds: 10));
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['error'], 'cancelled');
  });

  test('iptvCatalog job returns JSON off UI path', () async {
    final raw = await EngineJobs.run(
      EngineAsyncJob.iptvCatalog,
      {
        'requestJson': jsonEncode({
          'action': 'has_shelf',
          'portal_hash': 'parity-test',
          'section': 'live',
        }),
      },
    ).timeout(const Duration(seconds: 10));
    final m = jsonDecode(raw) as Map<String, dynamic>;
    // DB may be closed in unit tests — still must not hang / throw.
    expect(m.containsKey('has') || m.containsKey('error'), isTrue);
  });
}
