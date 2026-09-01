import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('formatTorrentEngineLoadingMessage', () {
    test('null stats → finding peers', () {
      expect(formatTorrentEngineLoadingMessage(null), 'Finding peers…');
    });

    test('zero peers → looking', () {
      expect(
        formatTorrentEngineLoadingMessage(
          const TorrentStats(
            downloadMbps: 0,
            uploadMbps: 0,
            activePeers: 0,
            totalPeers: 12,
            cachePercent: 0,
            loadedBytes: 0,
            totalBytes: 1,
            etaSeconds: null,
            hash: 'abc',
            isConnected: false,
          ),
        ),
        'Looking for peers… · 0/12 peers',
      );
    });

    test('peers + buffer', () {
      expect(
        formatTorrentEngineLoadingMessage(
          const TorrentStats(
            downloadMbps: 1.5,
            uploadMbps: 0,
            activePeers: 4,
            totalPeers: 20,
            cachePercent: 0,
            loadedBytes: 32768,
            totalBytes: 1 << 30,
            etaSeconds: null,
            hash: 'abc',
            isConnected: true,
          ),
        ),
        'Downloading from peers… · 4/20 peers · 1.50 MB/s · 32.0 KB buffered',
      );
    });

    test('connected peers, no data yet', () {
      final status = torrentLoadingStatusFromStats(
        const TorrentStats(
          downloadMbps: 0,
          uploadMbps: 0,
          activePeers: 3,
          totalPeers: 40,
          cachePercent: 0,
          loadedBytes: 0,
          totalBytes: 1 << 30,
          etaSeconds: null,
          hash: 'abc',
          isConnected: true,
        ),
      );
      expect(status.headline, 'Connecting to peers…');
      expect(status.activePeers, 3);
      expect(status.speedLabel, isNull);
      expect(status.bufferLabel, isNull);
      expect(
        status.displayMessage,
        'Connecting to peers… · 3/40 peers · buffering…',
      );
    });
  });
}
