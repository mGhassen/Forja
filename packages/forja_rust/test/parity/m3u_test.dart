import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('basic.m3u golden', () {
    final content = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/basic.m3u',
    ).readAsStringSync();
    final json = ForjaRust.instance.parseM3uJson(content);
    final list = jsonDecode(json) as List;
    expect(list.length, 1);
    expect(list.first['name'], 'News HD');
    expect(list.first['group'], 'News');
    expect(list.first['tvg_id'], 'ch1');
    expect(list.first['url'], 'http://stream.example/live');
  });

  test('crlf_extgrp.m3u golden', () {
    final content = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/crlf_extgrp.m3u',
    ).readAsStringSync();
    final json = ForjaRust.instance.parseM3uJson(content);
    final list = jsonDecode(json) as List;
    expect(list.length, 2);
    expect(list[0]['name'], 'Sports One');
    expect(list[0]['group'], 'Sports');
    expect(list[1]['name'], 'Sports Two');
    expect(list[1]['group'], 'OverrideGroup');
  });

  test('extgrp_before_extinf.m3u golden', () {
    final content = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/extgrp_before_extinf.m3u',
    ).readAsStringSync();
    final json = ForjaRust.instance.parseM3uJson(content);
    final list = jsonDecode(json) as List;
    expect(list.length, 2);
    expect(list[0]['group'], 'FromExtgrp');
    expect(list[1]['group'], '');
  });

  test('empty playlist returns error object', () {
    final json = ForjaRust.instance.parseM3uJson('');
    final decoded = jsonDecode(json);
    expect(decoded, isA<Map>());
    expect((decoded as Map)['error'], isNotNull);
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
