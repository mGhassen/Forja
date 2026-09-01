import 'package:flutter_test/flutter_test.dart';
import 'package:rust/src/playback/torrent/torrent_stream_service.dart';

void main() {
  test('TorrentDownloadCacheSnapshot.fromJson parses engine payload', () {
    const json =
        '{"cache_dir":"/tmp/torrent","disk_bytes":125644,"progress_bytes":'
        '500000000,"total_bytes":2000000000,"torrent_count":1,"active":true}';
    final snap = TorrentDownloadCacheSnapshot.fromJson(json);
    expect(snap.cacheDir, '/tmp/torrent');
    expect(snap.diskBytes, 125644);
    expect(snap.progressBytes, 500000000);
    expect(snap.totalBytes, 2000000000);
    expect(snap.torrentCount, 1);
    expect(snap.active, isTrue);
    expect(snap.displayBytes, 500000000);
    expect(snap.label(), contains('Downloading:'));
  });

  test('displayBytes prefers swarm progress over small disk footprint', () {
    const snap = TorrentDownloadCacheSnapshot(
      cacheDir: '/tmp/torrent',
      diskBytes: 128000,
      progressBytes: 900000000,
      totalBytes: 2000000000,
      torrentCount: 1,
      active: true,
    );
    expect(snap.displayBytes, 900000000);
    expect(snap.hasClearableData, isTrue);
    expect(snap.label(), 'Downloading: 858.3 MB / 1.9 GB');
  });

  test('idle disk cache still shows on the row', () {
    const snap = TorrentDownloadCacheSnapshot(
      cacheDir: '/tmp/torrent',
      diskBytes: 128000,
      progressBytes: 0,
      totalBytes: 0,
      torrentCount: 0,
      active: false,
    );
    expect(snap.displayBytes, 128000);
    expect(snap.label(), 'Torrent cache: 125.0 KB');
  });
}
