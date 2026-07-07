import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('parses master playlist', () {
    const masterUrl = 'https://cdn.example/master.m3u8';
    final body = File(
      '${_repoRoot()}/crates/utils/tests/fixtures/hls_master.m3u8',
    ).readAsStringSync();

    final rustJson = RustLib.instance.parseHlsMasterJson(masterUrl, body);
    final rustList = (jsonDecode(rustJson) as List)
        .cast<Map<String, dynamic>>();

    expect(rustList, isNotEmpty);
    expect(rustList.first['is_auto'], isTrue);

    final rust1080 = rustList.firstWhere((q) => q['label'] == '1080p');
    expect(rust1080['height'], 1080);
    expect(rust1080['url'], isNotEmpty);
  });
}

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/crates/ffi').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent.path;
}
