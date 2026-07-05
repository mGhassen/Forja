import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja_api/api/kisskh_subtitle_decryptor.dart';
import 'package:forja_api/api/torrent_filter.dart';
import 'package:forja_rust/forja_rust.dart';
import '../parity/dart_baseline/dart_baseline.dart';
import 'package:forja_webstreamr/webstreamr/utils/unpacker.dart';

import 'rust_engine.dart';

/// Wire Dart fallback backends for parity tests that call domain APIs
/// (TorrentFilter, KissKhSubtitleDecryptor, unpacker) alongside Rust FFI.
Future<void> initRustAndWireDartParityBackends() async {
  await initRustForTests();
  TorrentFilterBackend.normalizeTitle = TorrentFilterDart.normalizeTitle;
  TorrentFilterBackend.parseSceneInfo = TorrentFilterDart.parseSceneInfo;
  JsUnpackBackend.unpack = (source) {
    final out = ForjaRust.instance.unpackJs(source);
    return out.isEmpty ? null : out;
  };
  KissKhDecryptBackend.decryptBody = (body, sourceUrl) =>
      KissKhDecryptDart.decryptBody(body, sourceUrl: sourceUrl);
}

List<Map<String, dynamic>> m3uRowsFromRust(String content) {
  final json = ForjaRust.instance.parseM3uJson(content);
  final decoded = jsonDecode(json);
  if (decoded is Map && decoded['error'] != null) {
    throw FormatException(decoded['error'] as String);
  }
  return (decoded as List).cast<Map<String, dynamic>>();
}

List<Map<String, dynamic>> m3uRowsFromDart(String content) {
  return M3uDartParser.parse(content)
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

void expectM3uParity(String content, {String? reason}) {
  final rust = m3uRowsFromRust(content);
  final dart = m3uRowsFromDart(content);
  expect(rust.length, dart.length, reason: reason);
  for (var i = 0; i < rust.length; i++) {
    for (final key in ['name', 'url', 'logo', 'group', 'tvg_id', 'tvg_name']) {
      expect(rust[i][key], dart[i][key], reason: '$reason row $i $key');
    }
  }
}
