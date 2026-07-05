import 'dart:convert';

import 'package:api/api/kisskh_subtitle_decryptor.dart';
import 'package:api/api/torrent_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:webstreamr/webstreamr/utils/unpacker.dart';

import 'rust_engine.dart';

/// Wire Rust backends for parity tests that call domain APIs alongside FFI.
Future<void> initRustAndWireRustBackends() async {
  await initRustForTests();

  TorrentFilterBackend.normalizeTitle =
      (title) => ForjaRust.instance.normalizeTorrentTitle(title);

  TorrentFilterBackend.parseSceneInfo = (title) {
    final m = jsonDecode(ForjaRust.instance.parseSceneInfoJson(title))
        as Map<String, dynamic>;
    return {
      'season': m['season'],
      'episode': m['episode'],
      'isSeasonPack': m['is_season_pack'] ?? false,
      'isMultiEpisode': m['is_multi_episode'] ?? false,
      'isMultiSeason': m['is_multi_season'] ?? false,
      'matchIndex': m['match_index'] ?? -1,
    };
  };

  JsUnpackBackend.unpack = (source) {
    final out = ForjaRust.instance.unpackJs(source);
    return out.isEmpty ? null : out;
  };

  KissKhDecryptBackend.decryptBody = (body, sourceUrl) =>
      ForjaRust.instance.decryptKisskhBody(body, sourceUrl: sourceUrl);
}

List<Map<String, dynamic>> m3uRowsFromRust(String content) {
  final json = ForjaRust.instance.parseM3uJson(content);
  final decoded = jsonDecode(json);
  if (decoded is Map && decoded['error'] != null) {
    throw FormatException(decoded['error'] as String);
  }
  return (decoded as List).cast<Map<String, dynamic>>();
}
