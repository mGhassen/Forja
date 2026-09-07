// Shared live catalog wire helpers — stable host contract (RFC-073).
// Packs call liveCatalogStamp(row) before returning catalog rows.

function liveCatalogKind(raw) {
  var s = String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[/_\s]+/g, '-')
    .replace(/-+/g, '-');
  if (s.endsWith('-')) s = s.substring(0, s.length - 1);
  if (s === '24-7-streams' || s === '24-7-stream') return '24-7';
  if (s === 'soccer') return 'football';
  if (s === 'motorsports' || s === 'motor-sport') return 'motor-sports';
  if (s === 'miscellaneous' || s === 'misc') return 'other';
  if (s === 'afl') return 'australian-football';
  if (s === 'nfl' || s === 'ncaa-football' || s === 'college-football') {
    return 'american-football';
  }
  if (s === 'nba') return 'basketball';
  if (s === 'nhl') return 'hockey';
  return s || 'other';
}

function liveCatalogStamp(row, pluginId) {
  if (!row || typeof row !== 'object') return row;
  var id = String(row.id || '').trim();
  var kind = liveCatalogKind(
    row.kind || row.category || row.category_name || row.sport || '',
  );
  row.kind = kind;
  row.genres = [kind];
  row.category = kind;
  if (pluginId && !row.pluginId) row.pluginId = pluginId;

  var starts =
    row.startsAt != null
      ? row.startsAt
      : row.starts_at != null
        ? row.starts_at
        : row.date;
  if (starts != null && starts !== '') {
    var n = Number(starts);
    if (!isNaN(n) && n > 0) {
      row.startsAt = String(n > 1e12 ? n : Math.floor(n * 1000));
    } else {
      row.startsAt = String(starts);
    }
  }

  if (!row.open && id) {
    row.open = { surface: 'live', id: id };
  }
  if (row.airing == null && row.live === true) row.airing = true;
  if (!row.title && row.name) row.title = String(row.name);
  if (!row.title && row.event) row.title = String(row.event);
  return row;
}
