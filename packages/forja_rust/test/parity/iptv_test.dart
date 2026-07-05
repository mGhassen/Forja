import 'dart:convert';

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
}
