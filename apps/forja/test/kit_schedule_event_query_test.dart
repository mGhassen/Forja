import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/host/live_sports/schedule/kit_schedule_event_query.dart';

KitListEntry _entry({
  required String name,
  String kind = 'football',
  Map<String, dynamic>? row,
}) {
  return KitListEntry(
    meta: MetaItem(id: name, type: 'live_match', name: name),
    legacyRow: {
      'title': name,
      ...?row,
    },
    kind: kind,
  );
}

void main() {
  test('empty query matches everything', () {
    final e = _entry(name: 'Clydebank vs Alloa Athletic');
    expect(kitScheduleEntryMatchesQuery(e, ''), isTrue);
    expect(kitScheduleEntryMatchesQuery(e, '   '), isTrue);
  });

  test('matches title tokens', () {
    final e = _entry(name: 'Clydebank vs Alloa Athletic');
    expect(kitScheduleEntryMatchesQuery(e, 'clydebank'), isTrue);
    expect(kitScheduleEntryMatchesQuery(e, 'alloa'), isTrue);
    expect(kitScheduleEntryMatchesQuery(e, 'clyde alloa'), isTrue);
    expect(kitScheduleEntryMatchesQuery(e, 'arsenal'), isFalse);
  });

  test('matches teams and sport from row', () {
    final e = _entry(
      name: 'Match',
      kind: 'basketball',
      row: {
        'homeTeam': 'Lakers',
        'awayTeam': 'Celtics',
        'sport': 'Basketball',
      },
    );
    expect(kitScheduleEntryMatchesQuery(e, 'lakers'), isTrue);
    expect(kitScheduleEntryMatchesQuery(e, 'celtics basketball'), isTrue);
  });

  test('kitScheduleFilterEntries drops misses', () {
    final entries = [
      _entry(name: 'A vs B'),
      _entry(name: 'C vs D'),
    ];
    expect(kitScheduleFilterEntries(entries, 'c vs').single.meta.name, 'C vs D');
    expect(kitScheduleFilterEntries(entries, '').length, 2);
  });
}
