import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('searchTorrentsJson returns JSON array', () {
    final raw = RustLib.instance.searchTorrentsJson('ubuntu');
    final decoded = jsonDecode(raw);
    expect(decoded, isA<List>());
  });

  test('filter sort isVideo FFI chain', () {
    const rows = [
      {
        'name': 'Show S01E01 1080p',
        'magnet': 'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'seeders': '5',
        'size': '1 GB',
        'source': 'x',
      },
      {
        'name': 'Show S01E01 720p',
        'magnet': 'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'seeders': '50',
        'size': '500 MB',
        'source': 'x',
      },
    ];
    final filtered = jsonDecode(
      RustLib.instance.filterTorrentsJson(
        jsonEncode(rows),
        'Show',
        requiredSeason: 1,
        requiredEpisode: 1,
      ),
    ) as List;
    expect(filtered, hasLength(2));
    final sorted = jsonDecode(
      RustLib.instance.sortTorrentsJson(
        jsonEncode(filtered),
        'Seeders (High to Low)',
      ),
    ) as List;
    expect(sorted.first['seeders'], '50');
    expect(RustLib.instance.isVideoFile('a.mkv'), isTrue);
    expect(RustLib.instance.isVideoFile('nfo.txt'), isFalse);
  });
}
