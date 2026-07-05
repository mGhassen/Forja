import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:forja_rust/src/reference/iptv_dart_parse.dart';
import 'package:forja_rust/src/reference/pastesh_decrypt_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('decodeXtreamText matches Dart reference', () {
    const plain = 'News at Ten';
    final b64 = base64.encode(utf8.encode(plain));
    expect(ForjaRust.instance.decodeXtreamText(b64), IptvDartParse.decodeXtreamText(b64));
    expect(ForjaRust.instance.decodeXtreamText(b64), plain);
  });

  test('decodeXtreamText passes through plain text', () {
    const plain = 'Already plain';
    expect(ForjaRust.instance.decodeXtreamText(plain), IptvDartParse.decodeXtreamText(plain));
  });

  test('decryptPasteResponse matches Dart reference for invalid input', () {
    expect(ForjaRust.instance.decryptPasteResponse('bad', ''), PasteShDecryptDart.decryptRaw('bad', ''));
    expect(ForjaRust.instance.decryptPasteResponse('https://paste.sh/x#k', ''), PasteShDecryptDart.decryptRaw('https://paste.sh/x#k', ''));
  });

  test('parseXtreamCategoriesJson golden', () {
    final json = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/xtream_categories.json',
    ).readAsStringSync();
    final rustOut = jsonDecode(ForjaRust.instance.parseXtreamCategoriesJson(json)) as List;
    final dartOut = IptvDartParse.parseCategoriesRows(json);
    expect(rustOut.length, dartOut.length);
    expect(rustOut.first['name'], dartOut.first['name']);
    expect(rustOut.first['name'], 'Sports');
  });

  test('parseXtreamStreamsJson live golden', () {
    final json = File(
      '${_repoRoot()}/crates/forja-iptv-core/tests/fixtures/xtream_live_streams.json',
    ).readAsStringSync();
    final rustOut =
        jsonDecode(ForjaRust.instance.parseXtreamStreamsJson(json, 'live')) as List;
    final dartOut = IptvDartParse.parseStreamsRows(json, 'live');
    expect(rustOut.length, dartOut.length);
    expect(rustOut.first['stream_id'], dartOut.first['stream_id']);
    expect(rustOut.first['container_ext'], 'ts');
  });

  test('parseSeriesEpisodesRows normalizes get_series_info', () {
    const json = '''
{
  "episodes": {
    "1": [
      {
        "id": "100",
        "title": "Pilot",
        "container_extension": "mkv",
        "episode_num": 1,
        "info": {"plot": "First ep", "movie_image": "http://img/a.png"}
      }
    ],
    "2": [
      {
        "id": "200",
        "title": "Return",
        "episode_num": 3,
        "info": {"plot": "", "movie_image": ""}
      }
    ]
  }
}
''';
    final rows = IptvDartParse.parseSeriesEpisodesRows(json);
    expect(rows, hasLength(2));
    expect(rows.first['season'], 1);
    expect(rows.first['container_ext'], 'mkv');
    expect(rows.last['season'], 2);
    expect(rows.last['container_ext'], 'mp4');
    expect(rows.last['episode'], 3);
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
