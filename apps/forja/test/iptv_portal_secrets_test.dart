import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';

void main() {
  test('iptvPortalPasswordMapKey normalizes url|username', () {
    expect(
      iptvPortalPasswordMapKey(' https://X.tv ', ' User '),
      'https://x.tv|user',
    );
  });

  test('iptvPortalMetadataJson omits password', () {
    final v = VerifiedPortal(
      portal: const IptvPortal(
        url: 'http://p.example',
        username: 'u',
        password: 'secret',
        source: 'manual',
      ),
      label: 'Home',
      name: 'acct',
      expiry: 'Never',
      maxConnections: '2',
      activeConnections: '1',
    );
    final j = iptvPortalMetadataJson(v);
    expect(j.containsKey('password'), isFalse);
    expect(j['url'], 'http://p.example');
    expect(j['username'], 'u');
    expect(j['label'], 'Home');
  });
}
