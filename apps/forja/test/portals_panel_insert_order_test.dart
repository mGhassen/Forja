import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';

void main() {
  tearDown(() {
    for (final id in ['a', 'b', 'c', 'new', 'old', 'fav']) {
      PortalsHost.markPortalSeen(id);
    }
  });

  group('PortalsHost.favoritesFirstStable', () {
    test('favorites float up; sibling order unchanged', () {
      const a = PortalListItem(id: 'a', label: 'A');
      const b = PortalListItem(id: 'b', label: 'B');
      const fav = PortalListItem(id: 'fav', label: 'Fav', favorite: true);
      final out = PortalsHost.favoritesFirstStable([a, fav, b]);
      expect(out.map((e) => e.id).toList(), ['fav', 'a', 'b']);
    });

    test('no favorites keeps source order', () {
      const a = PortalListItem(id: 'a', label: 'A');
      const b = PortalListItem(id: 'b', label: 'B');
      const c = PortalListItem(id: 'c', label: 'C');
      final out = PortalsHost.favoritesFirstStable([a, b, c]);
      expect(out.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('new unshifted portal stays ahead of older siblings', () {
      // Vault after pack unshift: newest, then previous order.
      const neu = PortalListItem(id: 'new', label: 'New', isNew: true);
      const a = PortalListItem(id: 'a', label: 'A');
      const b = PortalListItem(id: 'b', label: 'B');
      final out = PortalsHost.favoritesFirstStable([neu, a, b]);
      expect(out.map((e) => e.id).toList(), ['new', 'a', 'b']);
    });
  });

  group('PortalsHost NEW badge session', () {
    test('register → isNew; markSeen clears', () {
      PortalsHost.registerPortalAdded('new');
      expect(PortalsHost.isNewPortal('new'), isTrue);
      PortalsHost.markPortalSeen('new');
      expect(PortalsHost.isNewPortal('new'), isFalse);
    });
  });
}
