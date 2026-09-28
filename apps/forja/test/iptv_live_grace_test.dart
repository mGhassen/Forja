import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/iptv_live_grace.dart';

void main() {
  group('iptvLiveGraceAction', () {
    test('forward position stays open', () {
      expect(
        iptvLiveGraceAction(
          playing: true,
          position: const Duration(seconds: 40),
          startPosition: const Duration(seconds: 30),
          playheadRecentlyMoved: true,
        ),
        IptvLiveGraceAction.hold,
      );
    });

    test('paused eof still reopens', () {
      expect(
        iptvLiveGraceAction(
          playing: false,
          position: const Duration(seconds: 30),
          startPosition: const Duration(seconds: 30),
          playheadRecentlyMoved: false,
        ),
        IptvLiveGraceAction.goLive,
      );
    });

    test('backward jump skips the archive instead of another reopen', () {
      expect(
        iptvLiveGraceAction(
          playing: true,
          position: const Duration(seconds: 4),
          startPosition: const Duration(seconds: 120),
          playheadRecentlyMoved: true,
        ),
        IptvLiveGraceAction.snapArchive,
      );
    });
  });

  group('iptvReconnectArchiveSkipSeconds', () {
    test('skips a typical panel archive and ignores jitter or PTS spikes', () {
      expect(iptvReconnectArchiveSkipSeconds(0.4), 0);
      expect(iptvReconnectArchiveSkipSeconds(15), 15);
      expect(iptvReconnectArchiveSkipSeconds(80), 0);
    });
  });
}
