import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/lan/lan_pairing_presence.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12);
  final nowSecs = now.millisecondsSinceEpoch ~/ 1000;

  group('LanPresence.desktop', () {
    test('hidden when not running', () {
      expect(
        LanPresence.desktop(
          running: false,
          hasDevices: true,
          lanTorrentActive: true,
        ),
        LanPresence.hidden,
      );
    });

    test('server stays up while waiting for pair', () {
      expect(
        LanPresence.desktop(
          running: true,
          hasDevices: false,
          lanTorrentActive: false,
        ),
        const LanPresence(
          server: LanServerMark.up,
          session: LanSessionMark.waiting,
        ),
      );
    });

    test('paired devices keep server up even with no recent traffic', () {
      expect(
        LanPresence.desktop(
          running: true,
          hasDevices: true,
          lanTorrentActive: false,
        ),
        const LanPresence(
          server: LanServerMark.up,
          session: LanSessionMark.paired,
        ),
      );
    });

    test('playing is session only — server stays up', () {
      expect(
        LanPresence.desktop(
          running: true,
          hasDevices: true,
          lanTorrentActive: true,
        ),
        const LanPresence(
          server: LanServerMark.up,
          session: LanSessionMark.playing,
        ),
      );
    });
  });

  group('LanPresence.client', () {
    test('hidden when unpaired', () {
      expect(
        LanPresence.client(
          paired: false,
          desktopOnline: true,
          lanTorrentActive: true,
        ),
        LanPresence.hidden,
      );
    });

    test('paired but desktop down keeps session paired', () {
      expect(
        LanPresence.client(
          paired: true,
          desktopOnline: false,
          lanTorrentActive: true,
        ),
        const LanPresence(
          server: LanServerMark.down,
          session: LanSessionMark.paired,
        ),
      );
    });

    test('desktop up + serving is playing session', () {
      expect(
        LanPresence.client(
          paired: true,
          desktopOnline: true,
          lanTorrentActive: true,
        ),
        const LanPresence(
          server: LanServerMark.up,
          session: LanSessionMark.playing,
        ),
      );
    });

    test('desktop up idle traffic is still paired not down', () {
      expect(
        LanPresence.client(
          paired: true,
          desktopOnline: true,
          lanTorrentActive: false,
        ),
        const LanPresence(
          server: LanServerMark.up,
          session: LanSessionMark.paired,
        ),
      );
    });
  });

  group('LanPresence helpers', () {
    test('deviceOnline uses the 120s window', () {
      expect(LanPresence.deviceOnline(nowSecs, now: now), isTrue);
      expect(LanPresence.deviceOnline(nowSecs - 120, now: now), isTrue);
      expect(LanPresence.deviceOnline(nowSecs - 121, now: now), isFalse);
      expect(LanPresence.deviceOnline(0, now: now), isFalse);
      expect(LanPresence.deviceOnline(null, now: now), isFalse);
    });

    test('lanTorrentActive matches history hash', () {
      expect(
        LanPresence.lanTorrentActive(
          {'info_hash': 'AbC'},
          [
            {'info_hash': 'abc'},
          ],
        ),
        isTrue,
      );
      expect(
        LanPresence.lanTorrentActive(
          {'info_hash': 'abc'},
          [
            {'info_hash': 'def'},
          ],
        ),
        isFalse,
      );
      expect(LanPresence.lanTorrentActive(null, const []), isFalse);
    });

    test('deviceTalk is per-device, not server status', () {
      const history = [
        {'info_hash': 'abc', 'device_id': 'tv-1'},
      ];
      expect(
        LanPresence.deviceTalk(
          deviceId: 'tv-1',
          lastSeen: nowSecs,
          active: {'info_hash': 'abc'},
          history: history,
          now: now,
        ),
        LanDeviceTalk.playing,
      );
      expect(
        LanPresence.deviceTalk(
          deviceId: 'phone',
          lastSeen: nowSecs,
          active: {'info_hash': 'abc'},
          history: history,
          now: now,
        ),
        LanDeviceTalk.active,
      );
      expect(
        LanPresence.deviceTalk(
          deviceId: 'phone',
          lastSeen: nowSecs - 121,
          active: {'info_hash': 'abc'},
          history: history,
          now: now,
        ),
        LanDeviceTalk.quiet,
      );
    });
  });
}
