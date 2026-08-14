import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('mergeByMagnet keeps the higher-seeder copy', () {
    final into = <String, Map<String, dynamic>>{};
    TorrentSearchProviders.mergeByMagnet(into, [
      {
        'name': 'a',
        'magnet': 'magnet:?xt=urn:btih:abc',
        'seeders': '10',
        'size': '1 GB',
        'source': 'YTS',
      },
    ]);
    TorrentSearchProviders.mergeByMagnet(into, [
      {
        'name': 'a-better',
        'magnet': 'magnet:?xt=urn:btih:abc',
        'seeders': '40',
        'size': '1 GB',
        'source': 'Knaben',
      },
      {
        'name': 'b',
        'magnet': 'magnet:?xt=urn:btih:def',
        'seeders': '2',
        'size': '2 GB',
        'source': 'Nyaa',
      },
    ]);
    expect(into.length, 2);
    expect(into['magnet:?xt=urn:btih:abc']!['source'], 'Knaben');
    expect(into['magnet:?xt=urn:btih:abc']!['seeders'], '40');
    expect(into['magnet:?xt=urn:btih:def']!['name'], 'b');
  });

  test('mergeByMagnet skips empty magnets', () {
    final into = <String, Map<String, dynamic>>{};
    TorrentSearchProviders.mergeByMagnet(into, [
      {'name': 'x', 'magnet': '', 'seeders': '9', 'size': '1 GB', 'source': 'YTS'},
    ]);
    expect(into, isEmpty);
  });
}
