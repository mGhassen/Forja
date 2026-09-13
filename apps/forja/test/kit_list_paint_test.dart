import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/host/layout/list/kit_list_entry.dart';
import 'package:forja/shared/host/layout/list/kit_list_paint.dart';
import 'package:forja_foundation/protocol/protocol.dart';

KitListEntry _entry({
  required String name,
  Map<String, dynamic>? row,
}) {
  return KitListEntry(
    meta: MetaItem(id: 't', type: 'live', name: name),
    legacyRow: row ?? const {},
    kind: 'football',
  );
}

void main() {
  group('KitListPaint.fromKitEntry', () {
    test('reads pack-emitted flat paint fields', () {
      final e = _entry(
        name: 'Fallback',
        row: {
          'title': 'Home vs Away',
          'poster': 'https://cdn.example/p.jpg',
          'category': 'football',
          'homeTeam': 'Home',
          'awayTeam': 'Away',
          'homeBadge': 'https://cdn.example/h.png',
          'awayBadge': 'https://cdn.example/a.png',
          'viewers': 1200,
          'airing': true,
          'alwaysLive': false,
          'dateMs': 0,
          'timeLabel': 'live',
          'scheduleLabel': '',
        },
      );
      final p = KitListPaint.fromKitEntry(e);
      expect(p.title, 'Home vs Away');
      expect(p.poster, 'https://cdn.example/p.jpg');
      expect(p.homeTeam, 'Home');
      expect(p.awayTeam, 'Away');
      expect(p.viewers, 1200);
      expect(p.isLive, isTrue);
      expect(p.timeLabel, 'live');
      expect(p.scheduleLabel, '');
    });

    test('drops non-absolute poster URLs', () {
      final e = _entry(
        name: 'X',
        row: {'poster': '/relative.jpg', 'timeLabel': '', 'scheduleLabel': ''},
      );
      expect(KitListPaint.fromKitEntry(e).poster, '');
    });

    test('alwaysLive from pack flag', () {
      final p = KitListPaint.fromKitEntry(
        _entry(name: 'TV', row: {'alwaysLive': true, 'category': '24/7'}),
      );
      expect(p.alwaysLive, isTrue);
      expect(p.isLive, isTrue);
    });
  });
}
