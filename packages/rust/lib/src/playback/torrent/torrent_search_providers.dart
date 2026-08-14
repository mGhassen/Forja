/// Builtin torrent search provider ids (must match `crates/scrapers` PROVIDER_IDS).
class TorrentSearchProviders {
  static const allId = 'all_torrents';

  static const knaben = 'knaben';
  static const pirateBay = 'pirate_bay';
  static const uindex = 'uindex';
  static const torrentsCsv = 'torrents_csv';
  static const nyaa = 'nyaa';
  static const yts = 'yts';
  static const solidTorrents = 'solid_torrents';
  static const therarbg = 'therarbg';
  static const torrentio = 'torrentio';

  static const all = <String>[
    knaben,
    pirateBay,
    uindex,
    torrentsCsv,
    nyaa,
    yts,
    solidTorrents,
    therarbg,
    torrentio,
  ];

  static const labels = <String, String>{
    knaben: 'Knaben',
    pirateBay: 'The Pirate Bay',
    uindex: 'UIndex',
    torrentsCsv: 'Torrents CSV',
    nyaa: 'Nyaa',
    yts: 'YTS',
    solidTorrents: 'SolidTorrents',
    therarbg: 'TheRARBG',
    torrentio: 'Torrentio',
  };

  /// Result `source` tags written by `crates/scrapers` (must match Rust
  /// `display_name` / HTML parsers).
  static const resultSources = <String, String>{
    knaben: 'Knaben',
    pirateBay: 'ThePirateBay',
    uindex: 'UIndex',
    torrentsCsv: 'Torrents CSV',
    nyaa: 'Nyaa',
    yts: 'YTS',
    solidTorrents: 'SolidTorrents',
    therarbg: 'TheRARBG',
    torrentio: 'Torrentio',
  };

  static String label(String id) => labels[id] ?? id;

  static bool isBuiltin(String id) => all.contains(id);

  /// Sources panel chip: All / a builtin provider / legacy Forja aggregate.
  static bool isBuiltinSearchChip(String id) =>
      id == allId || id == 'forja' || isBuiltin(id);

  /// `null` → search every Settings-enabled provider; else only [id].
  static List<String>? searchEnabledForChip(String id) {
    if (id == allId || id == 'forja') return null;
    if (isBuiltin(id)) return [id];
    return null;
  }

  static int seedersOfJson(Map<String, dynamic> row) {
    final raw = row['seeders']?.toString() ?? '0';
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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
    if (selectedChipId == allId ||
        selectedChipId == 'forja' ||
        selectedChipId == 'jackett' ||
        selectedChipId == 'prowlarr') {
      return true;
    }
    final expected = resultSources[selectedChipId];
    if (expected == null) return true;
    return resultSource == expected;
  }
}
