import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('normalizeTitle', () {
    const titles = [
      'Show.S03E07.1080p-WEB-DL',
      'The Movie: Part II (2024)',
      '',
    ];
    for (final title in titles) {
      expect(
        RustLib.instance.normalizeTorrentTitle(title),
        isA<String>(),
        reason: title,
      );
    }
  });

  test('parseSceneInfo golden', () {
    final raw = File(
      '${_repoRoot()}/crates/utils/tests/fixtures/torrent_filter.json',
    ).readAsStringSync();
    final cases = jsonDecode(raw) as List;
    for (final c in cases) {
      final title = c['title'] as String;
      final rustJson = RustLib.instance.parseSceneInfoJson(title);
      final rust = jsonDecode(rustJson) as Map<String, dynamic>;
      if (c['season'] != null) {
        expect(rust['season'], c['season'], reason: title);
      }
      if (c['episode'] != null) {
        expect(rust['episode'], c['episode'], reason: title);
      }
    }
  });

  test('filterTorrentsJson via FFI', () {
    const rows = [
      {
        'name': 'Scary Movie 2026 1080p WEB-DL',
        'magnet': 'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'seeders': '10',
        'size': '1 GB',
        'source': 'Knaben',
      },
      {
        'name': 'Other Show S01E01',
        'magnet': 'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'seeders': '5',
        'size': '500 MB',
        'source': 'TPB',
      },
    ];
    final out = jsonDecode(
      RustLib.instance.filterTorrentsJson(
        jsonEncode(rows),
        'Scary Movie',
      ),
    ) as List;
    expect(out, hasLength(1));
    expect(out.first['name'], contains('Scary Movie'));
  });

  test('sortTorrentsJson seeders high to low', () {
    const rows = [
      {
        'name': 'a',
        'magnet': 'm1',
        'seeders': '10',
        'size': '1 GB',
        'source': 'x',
      },
      {
        'name': 'b',
        'magnet': 'm2',
        'seeders': '100',
        'size': '2 GB',
        'source': 'x',
      },
    ];
    final out = jsonDecode(
      RustLib.instance.sortTorrentsJson(
        jsonEncode(rows),
        'Seeders (High to Low)',
      ),
    ) as List;
    expect(out.first['seeders'], '100');
    expect(out.last['seeders'], '10');
  });

  test('sortTorrentsJson size low to high', () {
    const rows = [
      {
        'name': 'big',
        'magnet': 'm1',
        'seeders': '1',
        'size': '10 GB',
        'source': 'x',
      },
      {
        'name': 'small',
        'magnet': 'm2',
        'seeders': '1',
        'size': '500 MB',
        'source': 'x',
      },
    ];
    final out = jsonDecode(
      RustLib.instance.sortTorrentsJson(
        jsonEncode(rows),
        'Size (Low to High)',
      ),
    ) as List;
    expect(out.first['name'], 'small');
    expect(out.last['name'], 'big');
  });

  test('isVideoFile via FFI', () {
    expect(RustLib.instance.isVideoFile('movie.mkv'), isTrue);
    expect(RustLib.instance.isVideoFile('readme.txt'), isFalse);
    expect(RustLib.instance.isVideoFile('clip.MP4'), isTrue);
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
