import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  const knabenHtml = '''
<table><tbody><tr>
<td class="text-wrap"><a href="magnet:?xt=urn:btih:abc" title="Show S01E01">Show</a></td>
<td>1.2 GB</td><td></td><td>100</td>
</tr></tbody></table>
''';

  const tpbHtml = '''
<table><tr>
<td><a class="detLink">Movie 1080p</a></td>
<td></td><td></td><td></td><td>2 GB</td><td>50</td>
<td><a href="magnet:?xt=urn:btih:deadbeef">M</a></td>
</tr></table>
''';

  test('parses knaben HTML row', () {
    final json = ForjaRust.instance.parseKnabenHtmlJson(knabenHtml);
    final list = jsonDecode(json) as List;
    expect(list, hasLength(1));
    expect(list.first['magnet'], startsWith('magnet:'));
  });

  test('parses TPB HTML row', () {
    final json = ForjaRust.instance.parseTpbHtmlJson(tpbHtml);
    final list = jsonDecode(json) as List;
    expect(list, hasLength(1));
    expect(list.first['name'], 'Movie 1080p');
  });

  test('dedup torrents by infohash', () {
    const rows = [
      {'name': 'A', 'magnet': 'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'seeders': '1', 'size': '1 GB', 'source': 'X'},
      {'name': 'B', 'magnet': 'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'seeders': '2', 'size': '1 GB', 'source': 'Y'},
      {'name': 'C', 'magnet': 'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'seeders': '3', 'size': '1 GB', 'source': 'Z'},
    ];
    final out = jsonDecode(
      ForjaRust.instance.dedupTorrentsJson(jsonEncode(rows)),
    ) as List;
    expect(out, hasLength(2));
  });
}
