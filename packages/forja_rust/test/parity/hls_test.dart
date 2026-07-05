import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:forja_rust/src/reference/hls_dart_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('parses master playlist — Rust vs Dart', () {
    const masterUrl = 'https://cdn.example/master.m3u8';
    final body = File(
      '${_repoRoot()}/crates/forja-utils/tests/fixtures/hls_master.m3u8',
    ).readAsStringSync();

    final dart = HlsDartParse.parseMaster(masterUrl, body)!;
    final rustJson = ForjaRust.instance.parseHlsMasterJson(masterUrl, body);
    final rustList = (jsonDecode(rustJson) as List)
        .cast<Map<String, dynamic>>();

    expect(rustList.length, dart.length);
    expect(rustList.first['is_auto'], isTrue);
    expect(dart.first.isAuto, isTrue);

    final rust1080 = rustList.firstWhere((q) => q['label'] == '1080p');
    final dart1080 = dart.firstWhere((q) => q.label == '1080p');
    expect(rust1080['url'], dart1080.url);
    expect(rust1080['height'], dart1080.height);
  });
}

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/crates/forja-ffi').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent.path;
}
