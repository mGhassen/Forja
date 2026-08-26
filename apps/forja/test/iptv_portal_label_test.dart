import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VerifiedPortal.displayLabel', () {
    const portal = IptvPortal(
      url: 'http://example.com',
      username: 'acct',
      password: 'secret',
    );

    test('prefers user label over API name and username', () {
      const v = VerifiedPortal(
        portal: portal,
        label: 'My provider',
        name: 'api_user',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      );
      expect(v.displayLabel, 'My provider');
    });

    test('falls back to API name when label empty', () {
      const v = VerifiedPortal(
        portal: portal,
        name: 'api_user',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      );
      expect(v.displayLabel, 'api_user');
    });

    test('falls back to username when label and name empty', () {
      const v = VerifiedPortal(
        portal: portal,
        name: '',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      );
      expect(v.displayLabel, 'acct');
    });

    test('withLabel trims and preserves other fields', () {
      const v = VerifiedPortal(
        portal: portal,
        name: 'api_user',
        expiry: '1 Jan 2030',
        maxConnections: '2',
        activeConnections: '1',
      );
      final labeled = v.withLabel('  Home  ');
      expect(labeled.label, 'Home');
      expect(labeled.name, 'api_user');
      expect(labeled.expiry, '1 Jan 2030');
      expect(labeled.maxConnections, '2');
    });

    test('withAccountFrom keeps known expiry with * when probe is Unknown', () {
      const v = VerifiedPortal(
        portal: portal,
        name: 'api_user',
        expiry: '16 Feb 2027',
        maxConnections: '1',
        activeConnections: '0',
      );
      const fresh = VerifiedPortal(
        portal: portal,
        name: 'api_user',
        expiry: 'Unknown',
        maxConnections: '1',
        activeConnections: '0',
      );
      expect(v.withAccountFrom(fresh).expiry, '16 Feb 2027*');
      expect(v.withAccountFrom(fresh).withAccountFrom(fresh).expiry, '16 Feb 2027*');
    });

    test('withAccountFrom replaces starred expiry when probe returns a date', () {
      const v = VerifiedPortal(
        portal: portal,
        name: 'api_user',
        expiry: '16 Feb 2027*',
        maxConnections: '1',
        activeConnections: '0',
      );
      const fresh = VerifiedPortal(
        portal: portal,
        name: 'api_user',
        expiry: '01 Mar 2028',
        maxConnections: '1',
        activeConnections: '0',
      );
      expect(v.withAccountFrom(fresh).expiry, '01 Mar 2028');
    });
  });

  group('IptvPortalExpiry.mergeOnProbe', () {
    test('does not wipe a known date with Unknown', () {
      expect(
        IptvPortalExpiry.mergeOnProbe('16 Feb 2027', 'Unknown'),
        '16 Feb 2027*',
      );
    });

    test('parse still reads starred dates', () {
      final d = IptvPortalExpiry.parse('16 Feb 2027*');
      expect(d, isNotNull);
      expect(d!.year, 2027);
      expect(d.month, 2);
      expect(d.day, 16);
    });
  });

  test('IptvStore round-trip preserves label', () async {
    const portal = IptvPortal(
      url: 'http://example.com',
      username: 'u',
      password: 'p',
      source: 'Manual',
    );
    await IptvStore.save(const [
      VerifiedPortal(
        portal: portal,
        label: 'Living room',
        name: 'Example',
        expiry: '',
        maxConnections: '1',
        activeConnections: '0',
      ),
    ]);
    final loaded = await IptvStore.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.label, 'Living room');
    expect(loaded.single.name, 'Example');
    expect(loaded.single.displayLabel, 'Living room');
  });

  test('IptvStore load defaults missing label to empty', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pt_iptv_verified_portals',
      '[{"url":"http://x","username":"u","password":"p","source":"Manual",'
      '"name":"Old","expiry":"","max":"1","active":"0"}]',
    );
    final loaded = await IptvStore.load();
    expect(loaded.single.label, '');
    expect(loaded.single.displayLabel, 'Old');
  });
}
