import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/torrent/torrent_stream_service.dart';

void main() {
  test('TorrentDiskCacheStats.fromJson parses reclaim payload', () {
    const json =
        '{"capacity_bytes":2147483648,"used_bytes":125644,"protected_bytes":0,'
        '"evictions":2,"reclaimed_bytes":50000,"over_budget":false}';
    final stats = TorrentDiskCacheStats.fromJson(json);
    expect(stats.usedBytes, 125644);
    expect(stats.protectedBytes, 0);
    expect(stats.reclaimedBytes, 50000);
    expect(stats.evictions, 2);
  });

  test('TorrentDiskCacheStats.fromJson returns empty on bad input', () {
    expect(TorrentDiskCacheStats.fromJson('not json'), TorrentDiskCacheStats.empty);
    expect(TorrentDiskCacheStats.fromJson(''), TorrentDiskCacheStats.empty);
  });
}
