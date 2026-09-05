import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('PlatformDefaults', () {
    test('android TV nav tabs are host-only', () {
      final tv = PlatformDefaults.forProfile(PlatformProfile.androidTv);
      expect(tv.visibleNavIds, ['iptv']);
    });

    test('android TV player defaults', () {
      final tv = PlatformDefaults.forProfile(PlatformProfile.androidTv);
      expect(tv.externalPlayer, 'Built-in Player');
      expect(tv.builtInPlayerEngine, BuiltInPlayerEngine.mediaKit);
      expect(tv.subSize, 52);
      expect(tv.subBottomPadding, 48);
      expect(tv.torrentDiskCacheGb, 1);
      expect(tv.playSourceWebstreaming, isFalse);
      expect(tv.playSourceTorrent, isFalse);
      expect(tv.playSourceStremio, isFalse);
      expect(tv.playSourceNuvio, isFalse);
      expect(tv.playSourceEngine, isTrue);
      expect(tv.playInBackground, isFalse);
    });

    test('phone defaults host-only nav', () {
      final phone = PlatformDefaults.forProfile(PlatformProfile.phone);
      expect(phone.visibleNavIds, PlatformDefaults.phoneNavIds);
      expect(phone.visibleNavIds, ['iptv']);
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
