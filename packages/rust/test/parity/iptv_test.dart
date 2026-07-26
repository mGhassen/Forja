import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('decodeXtreamText decodes base64', () {
    const plain = 'News at Ten';
    final b64 = base64.encode(utf8.encode(plain));
    expect(RustLib.instance.decodeXtreamText(b64), plain);
  });

  test('decodeXtreamText passes through plain text', () {
    const plain = 'Already plain';
    expect(RustLib.instance.decodeXtreamText(plain), plain);
  });

  test('decryptPasteResponse returns empty for invalid input', () {
    expect(RustLib.instance.decryptPasteResponse('bad', ''), '');
    expect(
      RustLib.instance.decryptPasteResponse('https://paste.sh/x#k', ''),
      '',
    );
  });

  test('parseXtreamCategoriesJson golden', () {
    final json = File(
      '${_repoRoot()}/crates/iptv/tests/fixtures/xtream_categories.json',
    ).readAsStringSync();
    final rustOut =
        jsonDecode(RustLib.instance.parseXtreamCategoriesJson(json)) as List;
    expect(rustOut.length, greaterThan(0));
    expect(rustOut.first['name'], 'Sports');
  });

  test('parseXtreamStreamsJson live golden', () {
    final json = File(
      '${_repoRoot()}/crates/iptv/tests/fixtures/xtream_live_streams.json',
    ).readAsStringSync();
    final rustOut =
        jsonDecode(RustLib.instance.parseXtreamStreamsJson(json, 'live'))
            as List;
    expect(rustOut.length, greaterThan(0));
    expect(rustOut.first['container_ext'], 'ts');
  });

  test('parseXtreamSeriesEpisodesJson golden', () {
    final json = File(
      '${_repoRoot()}/crates/iptv/tests/fixtures/xtream_series_info.json',
    ).readAsStringSync();
    final rustOut =
        jsonDecode(RustLib.instance.parseXtreamSeriesEpisodesJson(json))
            as List;
    expect(rustOut, hasLength(2));
    expect(rustOut.first['season'], 1);
    expect(rustOut.first['container_ext'], 'mkv');
    expect(rustOut.last['season'], 2);
    expect(rustOut.last['container_ext'], 'mp4');
    expect(rustOut.last['episode'], 3);
  });

  test('iptvPortalShareEncodeDecode round trip', () {
    final token = RustLib.instance.iptvPortalShareEncode(
      'http://portal.example.com:8080',
      'user1',
      'pass1',
    );
    expect(token.startsWith('F1.'), isTrue);
    final raw = RustLib.instance.iptvPortalShareDecode(token);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['url'], 'http://portal.example.com:8080');
    expect(map['username'], 'user1');
    expect(map['password'], 'pass1');
  });

  test('iptvPortalShareDecode rejects legacy short code', () {
    expect(RustLib.instance.iptvPortalShareDecode('FGNVUSEL'), '');
  });

  test('iptvProbeStreamJson rejects invalid url', () {
    final raw = RustLib.instance.iptvProbeStreamJson('not-a-url');
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    expect(parsed['error'], isNotNull);
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
