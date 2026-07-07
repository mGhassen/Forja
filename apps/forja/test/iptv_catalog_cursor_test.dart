import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';

void main() {
  test('parseRedditCatalogCursor starts at sub 0', () {
    final c = parseRedditCatalogCursor(null);
    expect(c.subIdx, 0);
    expect(c.after, isNull);
  });

  test('parseRedditCatalogCursor advances subreddit index', () {
    final c = parseRedditCatalogCursor('reddit:1:');
    expect(c.subIdx, 1);
    expect(c.after, isNull);
  });

  test('parseRedditCatalogCursor keeps pagination token', () {
    final c = parseRedditCatalogCursor('reddit:0:t3_abc123');
    expect(c.subIdx, 0);
    expect(c.after, 't3_abc123');
  });

  test('parseRedditCatalogCursor supports legacy reddit token', () {
    final c = parseRedditCatalogCursor('reddit:t3_legacy');
    expect(c.subIdx, 0);
    expect(c.after, 't3_legacy');
  });
}
