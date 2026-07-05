import 'dart:convert';
import 'dart:io';

import '../helpers/parity_backends.dart';
import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('basic.m3u golden — Rust vs Dart', () {
    final content = _fixture('basic.m3u');
    expectM3uParity(content, reason: 'basic.m3u');
    final list = m3uRowsFromRust(content);
    expect(list.length, 1);
    expect(list.first['name'], 'News HD');
  });

  test('crlf_extgrp.m3u golden — Rust vs Dart', () {
    final content = _fixture('crlf_extgrp.m3u');
    expectM3uParity(content, reason: 'crlf_extgrp.m3u');
    final list = m3uRowsFromRust(content);
    expect(list.length, 2);
    expect(list[0]['group'], 'Sports');
    expect(list[1]['group'], 'OverrideGroup');
  });

  test('extgrp_before_extinf.m3u golden — Rust vs Dart', () {
    final content = _fixture('extgrp_before_extinf.m3u');
    expectM3uParity(content, reason: 'extgrp_before_extinf.m3u');
    final list = m3uRowsFromRust(content);
    expect(list[0]['group'], 'FromExtgrp');
    expect(list[1]['group'], '');
  });

  test('empty playlist returns error object', () {
    final json = ForjaRust.instance.parseM3uJson('');
    final decoded = jsonDecode(json);
    expect(decoded, isA<Map>());
    expect((decoded as Map)['error'], isNotNull);
    expect(() => m3uRowsFromDart(''), throwsFormatException);
  });
}

String _fixture(String name) {
  return File(
    '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/$name',
  ).readAsStringSync();
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
