// Sport-chip id normalization and 24/7 / always-on filtering for Live Matches.
//
// Streamed tags always-on channels with a sport slug (`cricket`, `tennis`) and
// `date: 0`; the website groups those under **24/7**. PPV uses category
// `24/7 Streams` plus an `always_live` flag (often with stale start/end times).
// Both must land on the same chip and stay playable.

/// Canonical sport chip id across PPV / Streamed / CDN label variants.
String normalizeLiveSportId(String raw) {
  var s = raw.trim().toLowerCase().replaceAll(RegExp(r'[/_\s]+'), '-');
  s = s.replaceAll(RegExp(r'-+'), '-');
  if (s.endsWith('-')) s = s.substring(0, s.length - 1);
  const aliases = <String, String>{
    'motorsports': 'motor-sports',
    'motor-sport': 'motor-sports',
    'miscellaneous': 'other',
    'misc': 'other',
    'soccer': 'football',
    'afl': 'australian-football',
    'nfl': 'american-football',
    'nba': 'basketball',
    'nhl': 'hockey',
    '24-7-streams': '24-7',
    '24-7-stream': '24-7',
  };
  return aliases[s] ?? s;
}

String liveSportDisplayName(String raw, String normalizedId) {
  if (normalizedId == '24-7') return '24/7';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return normalizedId;
  if (trimmed.contains(RegExp(r'\s')) || trimmed != trimmed.toLowerCase()) {
    return trimmed;
  }
  return normalizedId
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

bool liveSportIdsMatch(String raw, String filterId) {
  if (filterId == 'all' || filterId.isEmpty) return true;
  final normalized = normalizeLiveSportId(raw);
  if (normalized.isEmpty) return false;
  return normalized == normalizeLiveSportId(filterId);
}

bool isLive247Sport(String raw) => normalizeLiveSportId(raw) == '24-7';

/// PPV `always_live` JSON - API sends `1`, `true`, or `"true"`.
bool parsePpvAlwaysLive(dynamic value) {
  if (value == true || value == 1) return true;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}

/// PPV `viewers` is often a JSON string (`"99"`), not a number.
int parsePpvViewers(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

/// PPV 24/7 playability - ignore expired windows when always-live / 24/7.
bool ppvStreamIsAlwaysOn({
  required bool alwaysLive,
  required String categoryName,
  required int startsAt,
  required int endsAt,
  required bool hasIframe,
}) {
  if (!hasIframe) return false;
  if (alwaysLive || isLive247Sport(categoryName)) return true;
  return startsAt == 0 && endsAt == 0;
}

/// Whether a PPV schedule row is airing (matches site **Live now**).
///
/// Uses start/end when present; also treats an active viewer count as live
/// (ppv.is is viewer-driven). A non-zero [viewers] count wins over schedule
/// walls — lobby / early doors / device clock skew still show ● LIVE and the
/// play affordance. Only drop viewer-driven live well past [endsAt].
bool ppvStreamIsLive({
  required bool isAlwaysOn,
  required String status,
  required int startsAt,
  required int endsAt,
  required int viewers,
  int? nowSecs,
}) {
  if (isAlwaysOn) return true;
  if (status.trim().toLowerCase() == 'live') return true;

  final now = nowSecs ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (startsAt > 0 && endsAt > startsAt && now >= startsAt && now <= endsAt) {
    return true;
  }
  // Live now on ppv.is is viewer-driven; keep airing while people are watching.
  if (viewers > 0) {
    if (startsAt > 0 && endsAt > startsAt) {
      final graceEnd = endsAt + const Duration(hours: 3).inSeconds;
      // Do not gate on earlyStart — cards with audience numbers must stay
      // playable even when kickoff is still hours away (or the clock is wrong).
      return now <= graceEnd;
    }
    return true;
  }
  return false;
}

/// PPV `24/7 Streams` category **or** always-on (`date` / start+end unset).
bool isLive247Item({required String category, required bool isAlwaysOn}) =>
    isAlwaysOn || isLive247Sport(category);

/// Hide 24/7 / always-on from All and other sports; show only on the 24/7 chip.
bool includeLiveMatchInSportFilter({
  required String category,
  required bool isAlwaysOn,
  required String sportFilter,
}) {
  final showing247 = normalizeLiveSportId(sportFilter) == '24-7';
  if (isLive247Item(category: category, isAlwaysOn: isAlwaysOn)) {
    return showing247;
  }
  return liveSportIdsMatch(category, sportFilter);
}
