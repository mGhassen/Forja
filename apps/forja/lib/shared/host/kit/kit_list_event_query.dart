import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/host/kit/kit_list_source.dart';

/// Session-only list search query (does not reload the feed).
final kitListEventQueryProvider = StateProvider<String>((ref) => '');

/// Whether the expanding search field is open on the kit top bar.
final kitListEventSearchOpenProvider = StateProvider<bool>((ref) => false);

bool kitListEntryMatchesQuery(KitListEntry entry, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  final row = entry.legacyRow;
  final game = row['sportMatchGame'];
  final gameMap = game is Map ? Map<String, dynamic>.from(game) : const {};
  final hay = [
    entry.meta.name,
    entry.kind,
    row['title'],
    row['name'],
    row['homeTeam'],
    row['awayTeam'],
    row['sport'],
    row['category'],
    row['league'],
    gameMap['title'],
    gameMap['homeTeam'],
    gameMap['awayTeam'],
    gameMap['sport'],
    gameMap['category'],
  ]
      .map((v) => (v ?? '').toString().trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .join(' ');
  final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  for (final t in tokens) {
    if (!hay.contains(t)) return false;
  }
  return true;
}

List<KitListEntry> kitListFilterEntries(
  List<KitListEntry> entries,
  String query,
) {
  final q = query.trim();
  if (q.isEmpty) return entries;
  return [
    for (final e in entries)
      if (kitListEntryMatchesQuery(e, q)) e,
  ];
}
