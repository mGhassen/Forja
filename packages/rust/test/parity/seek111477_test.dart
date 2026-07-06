import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  tearDown(() {
    RustLib.instance.seek111477Stop();
  });

  test('seek111477 returns error for unreachable upstream', () {
    final cacheDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}site111477_test_cache';
    final raw = RustLib.instance.seek111477StartJson(jsonEncode({
      'upstream_url': 'https://invalid.invalid/stream.bin',
      'headers': <String, String>{},
      'cache_dir': cacheDir,
    }));
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['error'], isNotNull);
    expect(map['url'], isNull);
    expect(RustLib.instance.seek111477IsRunning(), isFalse);
  });

  test('seek111477 stop clears running state', () {
    expect(RustLib.instance.seek111477IsRunning(), isFalse);
    RustLib.instance.seek111477Stop();
    expect(RustLib.instance.seek111477Port(), 0);
  });

  test('seek111477 purge cache accepts temp path', () {
    final cacheDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}site111477_purge_test';
    Directory(cacheDir).createSync(recursive: true);
    final raw = RustLib.instance.seek111477PurgeCacheJson(cacheDir);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['ok'], isTrue);
  });
}
