import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/kit/list/kit_list_entry.dart';

/// Session-only list search query — per hub chrome key.
final kitListEventQueryProvider =
    StateProvider.family<String, String>((ref, chromeKey) => '');

/// Expanding search chrome open — per hub chrome key.
final kitListEventSearchOpenProvider =
    StateProvider.family<bool, String>((ref, chromeKey) => false);

/// Generic filter on pack-emitted [searchText] (or meta name). No product fields.
bool kitListEntryMatchesQuery(KitListEntry entry, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = (entry.legacyRow['searchText'] ?? entry.meta.name)
      .toString()
      .trim()
      .toLowerCase();
  for (final t in q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty)) {
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
