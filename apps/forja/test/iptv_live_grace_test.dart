import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/iptv_live_grace.dart';

void main() {
  group('iptvLiveHwDecodeFailAction', () {
    test('desktop past cold open uses software decode once', () {
      expect(
        iptvLiveHwDecodeFailAction(
          insideIgnoreWindow: false,
          pastColdOpen: true,
          desktopSoftwareFallback: true,
        ),
        IptvHwDecodeFailAction.softwareDecode,
      );
    });

    test('seek or reconnect window still drops the line', () {
      expect(
        iptvLiveHwDecodeFailAction(
          insideIgnoreWindow: true,
          pastColdOpen: true,
          desktopSoftwareFallback: true,
        ),
        IptvHwDecodeFailAction.ignore,
      );
    });

    test('cold open stays on hardware', () {
      expect(
        iptvLiveHwDecodeFailAction(
          insideIgnoreWindow: false,
          pastColdOpen: false,
          desktopSoftwareFallback: true,
        ),
        IptvHwDecodeFailAction.holdCold,
      );
    });

    test('android past cold open uses grace', () {
      expect(
        iptvLiveHwDecodeFailAction(
          insideIgnoreWindow: false,
          pastColdOpen: true,
          desktopSoftwareFallback: false,
        ),
        IptvHwDecodeFailAction.grace,
      );
    });
  });

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

    test('hardware decode fail reopens even when the clock moved', () {
      expect(
        iptvLiveGraceAction(
          playing: true,
          position: const Duration(seconds: 23),
          startPosition: const Duration(seconds: 11),
          playheadRecentlyMoved: true,
          hwDecodeFail: true,
        ),
        IptvLiveGraceAction.goLive,
      );
    });

    test('hardware decode reasons are recognised', () {
      expect(iptvLiveGraceReasonIsHwDecodeFail('hw decode fail (live VT)'), isTrue);
      expect(iptvLiveGraceReasonIsHwDecodeFail('hardware decode failed'), isTrue);
      expect(iptvLiveGraceReasonIsHwDecodeFail('socket reset'), isFalse);
      expect(iptvLiveGraceReasonIsHwDecodeFail('completed'), isFalse);
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
