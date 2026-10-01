import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/portals/models.dart';

void main() {
  group('PortalChannelGuideOpen.matchPortal', () {
    const portal = Portal(
      url: 'http://cdn.example/c/',
      username: 'alice',
      password: 'secret',
      platform: PortalPlatform.xtream,
    );
    final verified = VerifiedPortal(
      portal: portal,
      name: 'alice',
      expiry: '',
      maxConnections: '1',
      activeConnections: '0',
    );
    final portals = [verified];
    final pack = PortalChannelGuideOpen.packPortalKey(portal);

    test('matches pack url|username key', () {
      expect(PortalChannelGuideOpen.matchPortal(portals, pack), verified);
    });

    test('matches portal.key', () {
      expect(PortalChannelGuideOpen.matchPortal(portals, portal.key), verified);
    });

    test('returns null when vault list empty', () {
      expect(PortalChannelGuideOpen.matchPortal(const [], pack), isNull);
    });
  });

  group('PortalChannelGuideOpen.stub', () {
    test('paints one channel so Search/Guide chrome can show', () {
      final guide = PortalChannelGuideOpen.stub(
        streamId: '42',
        title: 'VIP - NO EVENT',
        logoUrl: 'http://logo',
        categoryId: 'vip',
        playUrl: 'http://play/42',
      );
      expect(guide.channels, hasLength(1));
      expect(guide.channels.first.id, '42');
      expect(guide.channels.first.name, 'VIP - NO EVENT');
      expect(guide.initialGroupId, 'vip');
      expect(guide.groups, isNotEmpty);
    });
  });
}
