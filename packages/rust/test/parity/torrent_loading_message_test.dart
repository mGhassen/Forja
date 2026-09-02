import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('formatTorrentEngineLoadingMessage', () {
    test('null stats → finding peers', () {
      expect(
        formatTorrentEngineLoadingMessage(null),
        'Finding peers…',
      );
      expect(
        torrentLoadingStatusFromStats(null).hint,
        contains('256.0 KB'),
      );
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
        'Downloading from peers… · 4/20 peers · 1.50 MB/s · 32.0 KB cached',
      );
    });

    test('head progress toward playback start', () {
      final status = torrentLoadingStatusFromStats(
        const TorrentStats(
          downloadMbps: 2.0,
          uploadMbps: 0,
          activePeers: 30,
          totalPeers: 100,
          cachePercent: 0,
          loadedBytes: 90 << 20,
          totalBytes: 1 << 30,
          etaSeconds: null,
          hash: 'abc',
          isConnected: true,
          headReadBytes: 128 * 1024,
          headTargetBytes: 256 * 1024,
        ),
      );
      expect(status.headline, 'Preparing playback…');
      expect(status.hasHeadProgress, isTrue);
      expect(status.headProgressFraction, closeTo(0.5, 0.01));
      expect(status.hint, contains('128.0 KB of 256.0 KB'));
      expect(status.hint, contains('at current speed'));
      expect(status.headProgressLabel, '128.0 KB / 256.0 KB');
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
