import '../../models/torrent_result.dart';
import 'torrent_search_catalog.dart';

/// Builtin torrent search provider ids and chip helpers.
class TorrentSearchProviders {
  static const allId = 'all_torrents';
  static const noneId = 'none_torrents';

  static const knaben = 'knaben';
  static const pirateBay = 'pirate_bay';
  static const uindex = 'uindex';
  static const torrentsCsv = 'torrents_csv';
  static const nyaa = 'nyaa';
  static const yts = 'yts';
  static const solidTorrents = 'solid_torrents';
  static const therarbg = 'therarbg';
  static const torrentio = 'torrentio';

  static List<String> get all => TorrentSearchCatalog.allIds;

  static Map<String, String> get labels => TorrentSearchCatalog.labels;

  static Map<String, String> get resultSources =>
      TorrentSearchCatalog.resultSources;

  static String label(String id) => labels[id] ?? id;

  static bool isBuiltin(String id) => all.contains(id);

  /// Sources panel chip: All / a builtin provider / legacy Forja aggregate.
  static bool isBuiltinSearchChip(String id) =>
      id == allId || id == 'forja' || isBuiltin(id);

  static bool isAllChip(String id) => id == allId || id == 'forja';

  static bool isNoneChip(String id) => id == noneId;

  /// Tap All: if All is already on, clear every builtin chip; otherwise select All.
  static String nextIdAfterAllTap(String selectedSourceId) =>
      isAllChip(selectedSourceId) ? noneId : allId;

  /// `null` → search every Settings-enabled provider; else only those ids.
  static List<String>? searchEnabledForChip(String id) {
    if (id == noneId) return const [];
    if (id == allId || id == 'forja') return null;
    if (isBuiltin(id)) return [id];
    return null;
  }

  static String? idForResultSource(String resultSource) {
    for (final e in resultSources.entries) {
      if (e.value == resultSource) return e.key;
    }
    return null;
  }

  /// Settings-enabled providers the [chipId] should query.
  static List<String> enabledForChip(
    String chipId,
    Iterable<String> settingsEnabled,
  ) {
    if (chipId == noneId || chipId == 'jackett' || chipId == 'prowlarr') {
      return const [];
    }
    final allow = settingsEnabled.toSet();
    final chip = searchEnabledForChip(chipId);
    final ids = chip ?? all;
    return [for (final id in ids) if (allow.contains(id)) id];
  }

  static String defaultChipId(Iterable<String> settingsEnabled) {
    final enabled = enabledForChip(allId, settingsEnabled);
    return enabled.isEmpty ? allId : enabled.first;
  }

  static List<String> missingEnabledForChip({
    required String chipId,
    required Iterable<String> settingsEnabled,
    required Iterable<String> fetchedProviderIds,
  }) {
    final have = fetchedProviderIds.toSet();
    return [
      for (final id in enabledForChip(chipId, settingsEnabled))
        if (!have.contains(id)) id,
    ];
  }

  static void addFetchedFromResultSources(
    Set<String> fetched,
    Iterable<String> resultSources,
  ) {
    for (final src in resultSources) {
      final id = idForResultSource(src);
      if (id != null) fetched.add(id);
    }
  }

  static int seedersOfJson(Map<String, dynamic> row) {
    final raw = row['seeders']?.toString() ?? '0';
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  /// Stable key for per-indexer rows (same magnet may appear from many providers).
  static String searchRowKey(Map<String, dynamic> row) {
    final magnet = row['magnet']?.toString() ?? '';
    final source = row['source']?.toString() ?? '';
    return '$magnet|$source';
  }

  static String torrentResultKey(TorrentResult row) =>
      '${row.magnet}|${row.source}';

  /// Merge search batches without collapsing different indexers on the same magnet.
  static void mergeSearchRows(
    Map<String, Map<String, dynamic>> into,
    List<Map<String, dynamic>> batch,
  ) {
    for (final row in batch) {
      final key = searchRowKey(row);
      if (key == '|' || row['magnet']?.toString().isEmpty != false) continue;
      final existing = into[key];
      if (existing == null || seedersOfJson(row) > seedersOfJson(existing)) {
        into[key] = row;
      }
    }
  }

  /// One row per magnet — use only for All chip / play pick, not per-provider chips.
  static List<TorrentResult> dedupeTorrentResultsByMagnet(
    Iterable<TorrentResult> rows,
  ) {
    final byMagnet = <String, TorrentResult>{};
    for (final row in rows) {
      if (row.magnet.isEmpty) continue;
      final existing = byMagnet[row.magnet];
      if (existing == null || row.seedersCount > existing.seedersCount) {
        byMagnet[row.magnet] = row;
      }
    }
    return byMagnet.values.toList();
  }

  /// Merge [batch] into [into] keyed by magnet; keep the higher-seeder copy.
  static void mergeByMagnet(
    Map<String, Map<String, dynamic>> into,
    List<Map<String, dynamic>> batch,
  ) {
    for (final row in batch) {
      final magnet = row['magnet']?.toString() ?? '';
      if (magnet.isEmpty) continue;
      final existing = into[magnet];
      if (existing == null || seedersOfJson(row) > seedersOfJson(existing)) {
        into[magnet] = row;
      }
    }
  }

  /// Whether [resultSource] belongs to the selected Torrents chip.
  static bool matchesResultSource(String selectedChipId, String resultSource) {
    if (selectedChipId == noneId) return false;
    if (selectedChipId == allId ||
        selectedChipId == 'forja' ||
        selectedChipId == 'jackett' ||
        selectedChipId == 'prowlarr') {
      return true;
    }
    final expected = resultSources[selectedChipId];
    if (expected == null) return false;
    return resultSource == expected;
  }

  /// All chip: merge duplicate magnets when no view filter or 2+ filters.
  /// One view-filter chip → show that indexer raw (no cross-provider merge).
  static bool sourcesPanelMergeBest({
    required bool allChip,
    required int viewFilterCount,
  }) {
    if (!allChip) return false;
    if (viewFilterCount == 1) return false;
    return true;
  }

  /// Chip filter — prefer host-stamped [_providerId] over JS [source] label.
  static bool matchesTorrentRow(
    String selectedChipId,
    TorrentResult row,
  ) {
    if (selectedChipId == noneId) return false;
    if (selectedChipId == allId ||
        selectedChipId == 'forja' ||
        selectedChipId == 'jackett' ||
        selectedChipId == 'prowlarr') {
      return true;
    }
    final providerId = row.providerId;
    if (providerId != null && providerId.isNotEmpty) {
      return providerId == selectedChipId;
    }
    return matchesResultSource(selectedChipId, row.source);
  }
}
