import 'package:forja/features/iptv/data/models.dart';

/// CSV columns - keep in sync with `apps/web/src/lib/iptv-portal-csv.ts`.
const iptvPortalCsvHeaders = <String>[
  'label',
  'name',
  'url',
  'username',
  'password',
  'source',
  'platform',
  'expiry',
  'max',
  'active',
  'favorite',
];

const _headerAliases = <String, String>{
  'label': 'label',
  'name': 'name',
  'url': 'url',
  'username': 'username',
  'user': 'username',
  'password': 'password',
  'pass': 'password',
  'source': 'source',
  'platform': 'platform',
  'type': 'platform',
  'expiry': 'expiry',
  'expires': 'expiry',
  'max': 'max',
  'active': 'active',
  'favorite': 'favorite',
  'favourite': 'favorite',
};

class ParsedPortalCsvRow {
  const ParsedPortalCsvRow({required this.portal, this.favorite});

  final VerifiedPortal portal;
  final bool? favorite;
}

class ParsePortalsCsvResult {
  const ParsePortalsCsvResult({
    required this.portals,
    required this.skipped,
  });

  final List<ParsedPortalCsvRow> portals;
  final int skipped;
}

class MergePortalsCsvLogEntry {
  const MergePortalsCsvLogEntry({
    required this.status,
    required this.label,
    required this.url,
    required this.username,
  });

  /// `added` or `already_present`
  final String status;
  final String label;
  final String url;
  final String username;
}

class MergePortalsCsvResult {
  const MergePortalsCsvResult({
    required this.portals,
    required this.favoriteKeys,
    required this.added,
    required this.skippedExisting,
    required this.log,
  });

  final List<VerifiedPortal> portals;
  final Set<String> favoriteKeys;
  final int added;
  final int skippedExisting;
  final List<MergePortalsCsvLogEntry> log;
}

String _csvEscape(String value) {
  if (RegExp(r'[",\r\n]').hasMatch(value)) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Parse one CSV line into fields (RFC 4180 quotes).
List<String> parseCsvLine(String line) {
  final fields = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current.write(ch);
      }
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      continue;
    }
    if (ch == ',') {
      fields.add(current.toString());
      current = StringBuffer();
      continue;
    }
    current.write(ch);
  }
  fields.add(current.toString());
  return fields;
}

List<String> _splitCsvRows(String text) {
  final normalized = text
      .replaceFirst(RegExp(r'^\uFEFF'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rows = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < normalized.length; i++) {
    final ch = normalized[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < normalized.length && normalized[i + 1] == '"') {
        current.write('""');
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      current.write(ch);
      continue;
    }
    if (ch == '\n' && !inQuotes) {
      final row = current.toString();
      if (row.trim().isNotEmpty) rows.add(row);
      current = StringBuffer();
      continue;
    }
    current.write(ch);
  }
  final last = current.toString();
  if (last.trim().isNotEmpty) rows.add(last);
  return rows;
}

String? _normalizeHeader(String raw) {
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  return _headerAliases[key];
}

bool? _parseFavorite(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return null;
  if (const {'yes', 'y', 'true', '1', 'fav', 'favorite', 'favourite'}
      .contains(v)) {
    return true;
  }
  if (const {'no', 'n', 'false', '0'}.contains(v)) return false;
  return null;
}

/// Parse a CSV string produced by [portalsToCsv] (or a compatible export).
ParsePortalsCsvResult parsePortalsCsv(String text) {
  final rows = _splitCsvRows(text);
  if (rows.isEmpty) {
    throw StateError('CSV is empty');
  }

  final headerCells = parseCsvLine(rows.first).map((h) => h.trim()).toList();
  final mapped = headerCells.map(_normalizeHeader).toList();
  final knownCount = mapped.whereType<String>().length;

  late final Map<String, int> columnIndex;
  late final int dataStart;

  if (knownCount >= 2) {
    columnIndex = <String, int>{};
    for (var i = 0; i < mapped.length; i++) {
      final header = mapped[i];
      if (header != null) columnIndex[header] = i;
    }
    dataStart = 1;
  } else if (headerCells.length >= 3) {
    columnIndex = {
      for (var i = 0; i < iptvPortalCsvHeaders.length; i++)
        iptvPortalCsvHeaders[i]: i,
    };
    dataStart = 0;
  } else {
    throw StateError('CSV needs a header row (url, username, password, …)');
  }

  if (!columnIndex.containsKey('url') ||
      !columnIndex.containsKey('username') ||
      !columnIndex.containsKey('password')) {
    throw StateError('CSV must include url, username, and password columns');
  }

  String cell(List<String> cells, String header) {
    final idx = columnIndex[header];
    if (idx == null || idx >= cells.length) return '';
    return cells[idx].trim();
  }

  final portals = <ParsedPortalCsvRow>[];
  var skipped = 0;

  for (var r = dataStart; r < rows.length; r++) {
    final cells = parseCsvLine(rows[r]);
    final url = cell(cells, 'url');
    final username = cell(cells, 'username');
    final password = cell(cells, 'password');
    final platform = IptvPortalPlatform.fromString(cell(cells, 'platform'));
    final userOk = platform == IptvPortalPlatform.m3u
        ? url.isNotEmpty
        : (url.isNotEmpty && username.isNotEmpty);
    final passOk = platform == IptvPortalPlatform.xtream
        ? password.isNotEmpty
        : true;
    if (!userOk || !passOk) {
      skipped++;
      continue;
    }
    final portal = VerifiedPortal(
      portal: IptvPortal(
        url: url,
        username: platform == IptvPortalPlatform.m3u
            ? IptvPortalPlatform.m3uUsernameSentinel
            : username,
        password: password,
        source: cell(cells, 'source').isEmpty ? 'csv' : cell(cells, 'source'),
        platform: platform,
      ),
      label: cell(cells, 'label'),
      name: cell(cells, 'name'),
      expiry: cell(cells, 'expiry'),
      maxConnections: cell(cells, 'max').isEmpty ? '1' : cell(cells, 'max'),
      activeConnections:
          cell(cells, 'active').isEmpty ? '0' : cell(cells, 'active'),
    );
    portals.add(
      ParsedPortalCsvRow(
        portal: portal,
        favorite: _parseFavorite(cell(cells, 'favorite')),
      ),
    );
  }

  if (portals.isEmpty) {
    throw StateError(
      skipped > 0
          ? 'No valid portals found (need url, username, and password on each row)'
          : 'No portal rows found',
    );
  }

  return ParsePortalsCsvResult(portals: portals, skipped: skipped);
}

/// Add CSV portals that are not already in the list; never overwrite existing.
MergePortalsCsvResult mergePortalsFromCsv({
  required List<VerifiedPortal> existingPortals,
  required Set<String> existingFavorites,
  required List<ParsedPortalCsvRow> parsed,
}) {
  final byKey = <String, VerifiedPortal>{
    for (final p in existingPortals) p.key: p,
  };
  final favorites = Set<String>.from(existingFavorites);
  var added = 0;
  var skippedExisting = 0;
  final log = <MergePortalsCsvLogEntry>[];

  for (final row in parsed) {
    final key = row.portal.key;
    final label = row.portal.displayLabel;
    if (byKey.containsKey(key)) {
      skippedExisting++;
      log.add(
        MergePortalsCsvLogEntry(
          status: 'already_present',
          label: label,
          url: row.portal.portal.url,
          username: row.portal.portal.username,
        ),
      );
      continue;
    }
    byKey[key] = row.portal;
    added++;
    log.add(
      MergePortalsCsvLogEntry(
        status: 'added',
        label: label,
        url: row.portal.portal.url,
        username: row.portal.portal.username,
      ),
    );
    if (row.favorite == true) favorites.add(key);
  }

  return MergePortalsCsvResult(
    portals: byKey.values.toList(),
    favoriteKeys: favorites,
    added: added,
    skippedExisting: skippedExisting,
    log: log,
  );
}

/// Build a CSV string for Xtream portals (UTF-8, Excel-friendly BOM).
String portalsToCsv({
  required List<VerifiedPortal> portals,
  required Set<String> favoriteKeys,
}) {
  final lines = <String>[
    iptvPortalCsvHeaders.join(','),
    ...portals.map((portal) {
      final cells = <String>[
        portal.label.trim(),
        portal.name.trim(),
        portal.portal.url,
        portal.portal.username,
        portal.portal.password,
        portal.portal.source.trim(),
        portal.portal.platform.wire,
        portal.expiry.trim(),
        portal.maxConnections.trim(),
        portal.activeConnections.trim(),
        favoriteKeys.contains(portal.key) ? 'yes' : 'no',
      ];
      return cells.map(_csvEscape).join(',');
    }),
  ];
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

String iptvPortalsCsvFilename([DateTime? date]) {
  final d = date ?? DateTime.now();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return 'forja-iptv-portals-$y-$m-$day.csv';
}
