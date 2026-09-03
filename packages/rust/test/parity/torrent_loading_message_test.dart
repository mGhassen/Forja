import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('formatTorrentEngineLoadingMessage', () {
    test('null stats → preparing', () {
      expect(formatTorrentEngineLoadingMessage(null), 'Preparing playback…');
      expect(torrentLoadingStatusFromStats(null).hint, isNull);
    });

    test('zero peers → finding peers', () {
      expect(
        formatTorrentEngineLoadingMessage(
          const TorrentStats(
            downloadMbps: 0,
            uploadMbps: 0,
            activePeers: 0,
            totalPeers: 0,
            cachePercent: 0,
            loadedBytes: 0,
            totalBytes: 1,
            etaSeconds: null,
            hash: 'abc',
            isConnected: false,
          ),
        ),
        'Finding peers…',
      );
    });

    test('peers downloading → preparing', () {
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
        'Preparing playback…',
      );
    });

    test('head complete → opening player', () {
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
          headReadBytes: 256 * 1024,
          headTargetBytes: 256 * 1024,
        ),
      );
      expect(status.headline, 'Opening player…');
      expect(status.hint, isNull);
      expect(status.displayMessage, 'Opening player…');
    });

    test('head in progress → preparing', () {
      final status = torrentLoadingStatusFromStats(
        const TorrentStats(
          downloadMbps: 2.0,
          uploadMbps: 0,
          activePeers: 26,
          totalPeers: 2954,
          cachePercent: 0,
          loadedBytes: 256 << 20,
          totalBytes: 1 << 30,
          etaSeconds: null,
          hash: 'abc',
          isConnected: true,
          headReadBytes: 0,
          headTargetBytes: 256 * 1024,
        ),
      );
      expect(status.headline, 'Preparing playback…');
      expect(status.hint, isNull);
      expect(status.displayMessage, 'Preparing playback…');
    });
  });
}
