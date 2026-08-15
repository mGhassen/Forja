import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/lan/lan_pairing_presence.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12);
  final nowSecs = now.millisecondsSinceEpoch ~/ 1000;

  group('LanPresence.resolveServer', () {
    test('off when not running', () {
      expect(
        LanPresence.resolveServer(
          running: false,
          lastSeen: [nowSecs],
          lanTorrentActive: true,
        ),
        LanPresenceKind.off,
      );
    });

    test('waiting when listening with no devices', () {
      expect(
        LanPresence.resolveServer(
          running: true,
          lastSeen: const [],
          lanTorrentActive: false,
        ),
        LanPresenceKind.waiting,
      );
    });

    test('playing beats online', () {
      expect(
        LanPresence.resolveServer(
          running: true,
          lastSeen: [nowSecs],
          lanTorrentActive: true,
        ),
        LanPresenceKind.playing,
      );
    });

    test('ready when a device was seen recently', () {
      expect(
        LanPresence.resolveServer(
          running: true,
          lastSeen: [nowSecs - 30],
          lanTorrentActive: false,
          now: now,
        ),
        LanPresenceKind.ready,
      );
    });

    test('idle when every device is stale', () {
      expect(
        LanPresence.resolveServer(
          running: true,
          lastSeen: [nowSecs - 121],
          lanTorrentActive: false,
          now: now,
        ),
        LanPresenceKind.idle,
      );
    });
  });

  group('LanPresence.resolveClient', () {
    test('off when unpaired', () {
      expect(
        LanPresence.resolveClient(
          paired: false,
          desktopOnline: true,
          lanTorrentActive: true,
        ),
        LanPresenceKind.off,
      );
    });

    test('offline when desktop is down', () {
      expect(
        LanPresence.resolveClient(
          paired: true,
          desktopOnline: false,
          lanTorrentActive: true,
        ),
        LanPresenceKind.offline,
      );
    });

    test('playing when desktop is serving', () {
      expect(
        LanPresence.resolveClient(
          paired: true,
          desktopOnline: true,
          lanTorrentActive: true,
        ),
        LanPresenceKind.playing,
      );
    });

    test('ready when paired and desktop is up', () {
      expect(
        LanPresence.resolveClient(
          paired: true,
          desktopOnline: true,
          lanTorrentActive: false,
        ),
        LanPresenceKind.ready,
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

    test('devicePlaying requires owner device_id', () {
      const history = [
        {'info_hash': 'abc', 'device_id': 'tv-1'},
      ];
      expect(
        LanPresence.devicePlaying(
          deviceId: 'tv-1',
          active: {'info_hash': 'abc'},
          history: history,
        ),
        isTrue,
      );
      expect(
        LanPresence.devicePlaying(
          deviceId: 'phone',
          active: {'info_hash': 'abc'},
          history: history,
        ),
        isFalse,
      );
    });
  });
}
