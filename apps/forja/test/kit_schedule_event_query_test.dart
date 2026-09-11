import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/kit_list_event_query.dart';

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
    expect(kitListEntryMatchesQuery(e, ''), isTrue);
    expect(kitListEntryMatchesQuery(e, '   '), isTrue);
  });

  test('matches title tokens', () {
    final e = _entry(name: 'Clydebank vs Alloa Athletic');
    expect(kitListEntryMatchesQuery(e, 'clydebank'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'alloa'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'clyde alloa'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'arsenal'), isFalse);
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
    expect(kitListEntryMatchesQuery(e, 'lakers'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'celtics basketball'), isTrue);
  });

  test('kitListFilterEntries drops misses', () {
    final entries = [
      _entry(name: 'A vs B'),
      _entry(name: 'C vs D'),
    ];
    expect(kitListFilterEntries(entries, 'c vs').single.meta.name, 'C vs D');
    expect(kitListFilterEntries(entries, '').length, 2);
  });
}
