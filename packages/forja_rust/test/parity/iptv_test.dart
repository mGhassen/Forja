import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:flutter_test/flutter_test.dart';

String _dartDecodeXtream(String s) {
  if (s.isEmpty) return '';
  try {
    return utf8.decode(base64.decode(s), allowMalformed: true).trim();
  } catch (_) {
    return s;
  }
}

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('decodeXtreamText matches Dart base64 decode', () {
    const plain = 'News at Ten';
    final b64 = base64.encode(utf8.encode(plain));
    expect(ForjaRust.instance.decodeXtreamText(b64), _dartDecodeXtream(b64));
    expect(ForjaRust.instance.decodeXtreamText(b64), plain);
  });

  test('decodeXtreamText passes through plain text', () {
    const plain = 'Already plain';
    expect(ForjaRust.instance.decodeXtreamText(plain), _dartDecodeXtream(plain));
  });

  test('decryptPasteResponse returns empty for invalid input', () {
    expect(ForjaRust.instance.decryptPasteResponse('bad', ''), '');
    expect(ForjaRust.instance.decryptPasteResponse('https://paste.sh/x#k', ''), '');
  });

  test('parseXtreamCategoriesJson golden', () {
    final json = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/xtream_categories.json',
    ).readAsStringSync();
    final out = jsonDecode(ForjaRust.instance.parseXtreamCategoriesJson(json)) as List;
    expect(out.length, 2);
    expect(out.first['name'], 'Sports');
  });

  test('parseXtreamStreamsJson live golden', () {
    final json = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/xtream_live_streams.json',
    ).readAsStringSync();
    final out =
        jsonDecode(ForjaRust.instance.parseXtreamStreamsJson(json, 'live')) as List;
    expect(out.first['stream_id'], '42');
    expect(out.first['container_ext'], 'ts');
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
