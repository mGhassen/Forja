import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/models.dart';

void main() {
  group('IptvPortal.credKey', () {
    test('xtream ignores URL (same account on different hosts)', () {
      const a = IptvPortal(
        url: 'http://host-a.example',
        username: 'u',
        password: 'p',
      );
      const b = IptvPortal(
        url: 'http://host-b.example',
        username: 'u',
        password: 'p',
      );
      expect(a.credKey, b.credKey);
    });

    test('m3u includes URL so playlists stay distinct', () {
      const file = IptvPortal(
        url: 'file:///Users/me/fr.m3u',
        username: IptvPortalPlatform.m3uUsernameSentinel,
        password: '',
        platform: IptvPortalPlatform.m3u,
      );
      const remote = IptvPortal(
        url: 'https://iptv-org.github.io/iptv/index.m3u',
        username: IptvPortalPlatform.m3uUsernameSentinel,
        password: '',
        platform: IptvPortalPlatform.m3u,
      );
      expect(file.credKey, isNot(remote.credKey));
      expect(file.credKey, contains('file:///'));
      expect(remote.credKey, contains('iptv-org.github.io'));
    });

    test('m3u same URL still collides', () {
      const a = IptvPortal(
        url: 'https://example.com/list.m3u',
        username: IptvPortalPlatform.m3uUsernameSentinel,
        password: '',
        platform: IptvPortalPlatform.m3u,
      );
      const b = IptvPortal(
        url: 'https://example.com/list.m3u',
        username: IptvPortalPlatform.m3uUsernameSentinel,
        password: '',
        platform: IptvPortalPlatform.m3u,
      );
      expect(a.credKey, b.credKey);
    });
  });
}
