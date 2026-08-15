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
      expect(tv.torrentDiskCacheGb, 1);
      expect(tv.playSourceWebstreaming, isTrue);
      expect(tv.playSourceTorrent, isTrue);
      expect(tv.playSourceStremio, isTrue);
      expect(tv.playSourceNuvio, isTrue);
      expect(tv.playInBackground, isFalse);
    });

    test('phone defaults unchanged', () {
      final phone = PlatformDefaults.forProfile(PlatformProfile.phone);
      expect(phone.visibleNavIds, PlatformDefaults.phoneNavIds);
      expect(phone.builtInPlayerEngine, BuiltInPlayerEngine.mediaKit);
      expect(phone.subSize, 24);
      expect(phone.torrentDiskCacheGb, 1);
      expect(phone.playInBackground, isFalse);
    });

    test('desktop subtitle size', () {
      final desktop = PlatformDefaults.forProfile(PlatformProfile.desktop);
      expect(desktop.subSize, 44);
      expect(desktop.visibleNavIds, PlatformDefaults.phoneNavIds);
      expect(desktop.playInBackground, isTrue);
      expect(desktop.torrentDiskCacheGb, 2);
    });
  });
}
