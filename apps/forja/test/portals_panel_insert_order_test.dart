import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';

void main() {
  tearDown(() {
    // Clear session NEW keys between tests (mark every known id seen).
    for (final id in ['a', 'b', 'c', 'new', 'old', 'fav']) {
      PortalsHost.markPortalSeen(id);
    }
  });

  group('PortalsHost.comparePortalListItems', () {
    test('favorites first, then newest addedAt', () {
      const a = PortalListItem(id: 'old', label: 'Old');
      const b = PortalListItem(id: 'new', label: 'New');
      const fav = PortalListItem(id: 'fav', label: 'Fav', favorite: true);
      final ms = <String, int>{'old': 1000, 'new': 2000, 'fav': 500};
      final list = [a, b, fav]
        ..sort(
          (x, y) => PortalsHost.comparePortalListItems(x, y, addedAtMs: ms),
        );
      expect(list.map((e) => e.id).toList(), ['fav', 'new', 'old']);
    });

    test('missing addedAt sorts oldest', () {
      const a = PortalListItem(id: 'a', label: 'A');
      const b = PortalListItem(id: 'b', label: 'B');
      final ms = <String, int>{'b': 1000};
      final list = [a, b]
        ..sort(
          (x, y) => PortalsHost.comparePortalListItems(x, y, addedAtMs: ms),
        );
      expect(list.map((e) => e.id).toList(), ['b', 'a']);
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
