import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';

void main() {
  test('encode/decode round-trips categories and streams', () {
    const cats = [
      IptvCategory(id: '1', name: 'Sports'),
      IptvCategory(id: '2', name: 'News'),
    ];
    const streams = [
      IptvStream(
        streamId: '10',
        name: 'ESPN',
        icon: 'https://x/espn.png',
        categoryId: '1',
        containerExt: 'ts',
        kind: 'live',
        epgChannelId: 'espn',
      ),
    ];

    final raw = IptvCatalogDiskStore.encodeForTest(cats, streams);
    final snap = IptvCatalogDiskStore.decodeForTest(raw);
    expect(snap, isNotNull);
    expect(snap!.categories, hasLength(2));
    expect(snap.categories.first.name, 'Sports');
    expect(snap.streams, hasLength(1));
    expect(snap.streams.first.streamId, '10');
    expect(snap.streams.first.epgChannelId, 'espn');
  });

  test('decode rejects wrong version', () {
    final raw = IptvCatalogDiskStore.encodeForTest(const [], const []);
    final broken = raw.replaceFirst('"v":1', '"v":99');
    expect(IptvCatalogDiskStore.decodeForTest(broken), isNull);
  });
}
