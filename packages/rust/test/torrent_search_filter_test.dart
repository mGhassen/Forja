import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/torrent/torrent_search_filter.dart';

void main() {
  test('partitionSearchRows passes torrentio through title filter', () {
    final rows = [
      {
        'name': 'Unrelated.Release.2024',
        'magnet': 'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'seeders': '10',
        'size': '1 GB',
        'source': 'Torrentio',
        '_providerId': 'torrentio',
      },
      {
        'name': 'Other Show S01E01',
        'magnet': 'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'seeders': '5',
        'size': '500 MB',
        'source': 'Knaben',
        '_providerId': 'knaben',
      },
    ];
    final parts = TorrentSearchFilter.partitionSearchRows(rows);
    expect(parts.passThrough, hasLength(1));
    expect(parts.passThrough.first['_providerId'], 'torrentio');
    expect(parts.titleFilter, hasLength(1));
    expect(parts.titleFilter.first['_providerId'], 'knaben');
  });
}
