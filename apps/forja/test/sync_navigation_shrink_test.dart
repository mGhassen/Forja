import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';

void main() {
  group('navigationWouldShrinkCloud', () {
    test('false when remote has no visibleIds', () {
      expect(
        SyncDomainBridge.navigationWouldShrinkCloud(null, {
          'visibleIds': ['asian_drama', 'anime'],
        }),
        isFalse,
      );
      expect(
        SyncDomainBridge.navigationWouldShrinkCloud(const {
          'visibleIds': <String>[],
        }, {
          'visibleIds': ['asian_drama'],
        }),
        isFalse,
      );
    });

    test('false when local keeps every remote tab', () {
      expect(
        SyncDomainBridge.navigationWouldShrinkCloud(
          {
            'visibleIds': ['search', 'home', 'asian_drama', 'anime'],
          },
          {
            'visibleIds': [
              'search',
              'home',
              'asian_drama',
              'anime',
              'iptv',
            ],
          },
        ),
        isFalse,
      );
    });

    test('true when local drops home/search that cloud still has', () {
      expect(
        SyncDomainBridge.navigationWouldShrinkCloud(
          {
            'visibleIds': [
              'search',
              'home',
              'asian_drama',
              'anime',
              'iptv',
              'live_matches',
              'mylist',
            ],
          },
          {
            'visibleIds': [
              'asian_drama',
              'anime',
              'iptv',
              'live_matches',
              'mylist',
            ],
          },
        ),
        isTrue,
      );
    });
  });
}
