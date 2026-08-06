import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('PlatformDefaults', () {
    test('android TV nav tabs', () {
      final tv = PlatformDefaults.forProfile(PlatformProfile.androidTv);
      expect(
        tv.visibleNavIds,
        [
          'home',
          'asian_drama',
          'anime',
          'iptv',
          'live_matches',
          'mylist',
        ],
      );
    });

    test('android TV player defaults', () {
      final tv = PlatformDefaults.forProfile(PlatformProfile.androidTv);
      expect(tv.externalPlayer, 'Built-in Player');
      expect(tv.builtInPlayerEngine, BuiltInPlayerEngine.mediaKit);
      expect(tv.subSize, 52);
      expect(tv.subBottomPadding, 48);
      expect(tv.torrentRamCacheMb, 128);
      expect(tv.playSourceWebstreaming, isTrue);
      expect(tv.playSourceTorrent, isFalse);
      expect(tv.playSourceStremio, isFalse);
      expect(tv.playSourceNuvio, isFalse);
    });

    test('phone defaults unchanged', () {
      final phone = PlatformDefaults.forProfile(PlatformProfile.phone);
      expect(phone.visibleNavIds, PlatformDefaults.phoneNavIds);
      expect(phone.builtInPlayerEngine, BuiltInPlayerEngine.mediaKit);
      expect(phone.subSize, 24);
      expect(phone.torrentRamCacheMb, 200);
    });

    test('desktop subtitle size', () {
      final desktop = PlatformDefaults.forProfile(PlatformProfile.desktop);
      expect(desktop.subSize, 44);
      expect(desktop.visibleNavIds, PlatformDefaults.phoneNavIds);
    });
  });
}
