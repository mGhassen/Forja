import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/host/layout/list/kit_list_entry.dart';
import 'package:forja/shared/host/layout/list/list_event_query.dart';
import 'package:forja_foundation/protocol/protocol.dart';

KitListEntry _entry({
  required String name,
  String kind = 'football',
  Map<String, dynamic>? row,
}) {
  return KitListEntry(
    meta: MetaItem(id: 't', type: 'live', name: name),
    legacyRow: row ?? const {},
    kind: kind,
  );
}

void main() {
  test('empty query matches everything', () {
    final e = _entry(name: 'Clydebank');
    expect(kitListEntryMatchesQuery(e, ''), isTrue);
    expect(kitListEntryMatchesQuery(e, '   '), isTrue);
  });

  test('matches pack searchText tokens', () {
    final e = _entry(
      name: 'Ignore',
      row: {'searchText': 'clydebank alloa athletic football'},
    );
    expect(kitListEntryMatchesQuery(e, 'clydebank'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'alloa'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'clyde alloa'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'arsenal'), isFalse);
  });

  test('falls back to meta name when searchText missing', () {
    final e = _entry(name: 'Lakers vs Celtics');
    expect(kitListEntryMatchesQuery(e, 'lakers'), isTrue);
    expect(kitListEntryMatchesQuery(e, 'celtics'), isTrue);
  });

  test('kitListFilterEntries drops misses', () {
    final entries = [
      _entry(name: 'A', row: {'searchText': 'alpha'}),
      _entry(name: 'B', row: {'searchText': 'beta'}),
    ];
    expect(kitListFilterEntries(entries, 'alpha').single.meta.name, 'A');
  });
}
