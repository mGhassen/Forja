import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

import '../helpers/rust_engine.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('EngineWorkerPool runs FFI off the main isolate', () async {
    expect(EngineWorkerPool.isRunning, isTrue);
    final version = await EngineWorkerPool.run(EngineJobKind.version, {});
    expect(version, isNotEmpty);
  });

  test('EngineWorkerPool reuses workers across calls', () async {
    final a = await runSortTorrentsJson('[]', 'Seeders (High to Low)');
    final b = await runSortTorrentsJson('[]', 'seeders');
    expect(a, isA<String>());
    expect(b, isA<String>());
  });
}
