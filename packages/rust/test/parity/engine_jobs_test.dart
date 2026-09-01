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

}
