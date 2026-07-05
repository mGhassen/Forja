import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_api/api/torrent_filter.dart';
import 'package:forja_rust/forja_rust.dart';
import 'package:forja_rust/src/reference/torrent_filter_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
    TorrentFilterBackend.normalizeTitle = TorrentFilterDart.normalizeTitle;
    TorrentFilterBackend.parseSceneInfo = TorrentFilterDart.parseSceneInfo;
  });

  test('normalizeTitle parity', () {
    const titles = [
      'Show.S03E07.1080p-WEB-DL',
      'The Movie: Part II (2024)',
      '',
    ];
    for (final title in titles) {
      expect(
        ForjaRust.instance.normalizeTorrentTitle(title),
        TorrentFilter.normalizeTitle(title),
        reason: title,
      );
    }
  });

  test('parseSceneInfo golden parity', () {
    final raw = File(
      '${_repoRoot()}/crates/forja-utils/tests/fixtures/torrent_filter.json',
    ).readAsStringSync();
    final cases = jsonDecode(raw) as List;
    for (final c in cases) {
      final title = c['title'] as String;
      final dart = TorrentFilter.parseSceneInfo(title);
      final rustJson = ForjaRust.instance.parseSceneInfoJson(title);
      final rust = jsonDecode(rustJson) as Map<String, dynamic>;

      expect(rust['season'], dart['season'], reason: title);
      expect(rust['episode'], dart['episode'], reason: title);
      if (c['is_season_pack'] == true) {
        expect(rust['is_season_pack'], dart['isSeasonPack'], reason: title);
      }
      if (c['is_multi_season'] == true) {
        expect(rust['is_multi_season'], dart['isMultiSeason'], reason: title);
      }
    }
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
