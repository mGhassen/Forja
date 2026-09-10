/// Generic Stremio sport/live meta signals for Live Sports schedule filters.
///
/// Shape-based only — no addon ids, hostnames, or pack names. Any live addon
/// that uses common Stremio fields (`releaseInfo`, description, genres, poster
/// badge query, `Time:` + calendar date) gets the same treatment.
library;

bool stremioMetaLooksUpcoming({
  required Iterable genres,
  required String descriptionUpper,
}) {
  for (final g in genres) {
    final s = g.toString().toUpperCase();
    if (s.contains('UPCOMING')) return true;
  }
  return descriptionUpper.contains('CATEGORY: UPCOMING');
}

final _stremioTimeClockRe = RegExp(
  r'TIME:\s*\d{1,2}:\d{2}',
  caseSensitive: false,
);

final _stremioCalendarDateRe = RegExp(
  r'(\d{1,2})\s*(?:[–\-—]\s*\d{1,2}\s+)?'
  r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
  r'(\d{4})',
  caseSensitive: false,
);

bool stremioTitleHasCalendarDate(String title) =>
    _stremioCalendarDateRe.hasMatch(title);

bool stremioDescriptionHasScheduleClock(String descriptionUpper) =>
    _stremioTimeClockRe.hasMatch(descriptionUpper);

/// Whether a Stremio meta should count as live / airing (not merely listed).
bool stremioMetaLooksLive({
  required String releaseInfoUpper,
  required String descriptionUpper,
  required String poster,
  required Iterable genres,
}) {
  if (stremioMetaLooksUpcoming(
    genres: genres,
    descriptionUpper: descriptionUpper,
  )) {
    return false;
  }
  if (releaseInfoUpper.contains('LIVE')) return true;
  if (descriptionUpper.contains('LIVE NOW')) return true;
  if (descriptionUpper.contains('LIVE TV')) return true;
  // Common poster badge query used by live catalogs (`…?badge=LIVE`).
  if (poster.toUpperCase().contains('BADGE=LIVE')) return true;
  for (final g in genres) {
    final s = g.toString().toUpperCase().trim();
    if (s.isEmpty) continue;
    if (s == 'LIVE TV' || s == 'LIVE') return true;
    if (s.contains(' LIVE') || s.startsWith('LIVE ')) return true;
  }
  return false;
}

/// Always-on / 24/7 feed: live badge, no kickoff epoch, no schedule clock/date.
bool stremioMetaIsAlwaysOnChannel({
  required bool looksLive,
  required int dateMs,
  required String descriptionUpper,
  required String title,
  required Iterable genres,
}) {
  if (!looksLive || dateMs > 0) return false;
  // Fixture-shaped rows keep a clock and/or calendar date even when epoch
  // parse fails — those are events, not 24/7 channels.
  if (stremioDescriptionHasScheduleClock(descriptionUpper)) return false;
  if (stremioTitleHasCalendarDate(title)) return false;

  if (descriptionUpper.contains('IPTV')) return true;
  if (descriptionUpper.contains('LIVE TV')) return true;

  var sawChannelGenre = false;
  for (final g in genres) {
    final c = g.toString().toLowerCase().trim();
    if (c.isEmpty) continue;
    if (c == 'live tv' ||
        c == '24/7' ||
        c == '24-7' ||
        c == 'iptv' ||
        c == 'live') {
      sawChannelGenre = true;
      continue;
    }
    // Any other genre ⇒ not a bare channel row.
    return false;
  }
  return sawChannelGenre;
}

/// Prefer a specific genre over generic Live TV / Sports labels.
String stremioCategoryFromGenres(Iterable? genres) {
  if (genres == null) return '';
  const skip = {
    'live tv',
    'live',
    'tv',
    'sports',
    'sport',
  };
  String? fallback;
  for (final g in genres) {
    final s = g.toString().trim();
    if (s.isEmpty) continue;
    fallback ??= s;
    final lower = s.toLowerCase();
    if (skip.contains(lower)) continue;
    if (lower.contains('upcoming')) continue;
    return s;
  }
  return fallback ?? '';
}

const _stremioMonths = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

int? _stremioMonthNum(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s.length < 3) return null;
  return _stremioMonths[s.substring(0, 3)];
}

/// Same-month: `7 – 13 September 2026`
final _stremioSameMonthRangeRe = RegExp(
  r'(\d{1,2})\s*[–\-—]\s*(\d{1,2})\s+'
  r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
  r'(\d{4})',
  caseSensitive: false,
);

/// Cross-month: `23 August – 13 September 2026`
final _stremioCrossMonthRangeRe = RegExp(
  r'(\d{1,2})\s+'
  r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*'
  r'[–\-—]\s*'
  r'(\d{1,2})\s+'
  r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
  r'(\d{4})',
  caseSensitive: false,
);

/// Single day: `22 August 2026`
final _stremioSingleDayRe = RegExp(
  r'(\d{1,2})\s+'
  r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
  r'(\d{4})',
  caseSensitive: false,
);

/// Inclusive UTC day window from a Flix / sports title date (or range).
({DateTime start, DateTime end})? stremioParseTitleDateRange(String title) {
  final cross = _stremioCrossMonthRangeRe.firstMatch(title);
  if (cross != null) {
    final y = int.tryParse(cross.group(5)!);
    final d0 = int.tryParse(cross.group(1)!);
    final d1 = int.tryParse(cross.group(3)!);
    final m0 = _stremioMonthNum(cross.group(2));
    final m1 = _stremioMonthNum(cross.group(4));
    if (y != null && d0 != null && d1 != null && m0 != null && m1 != null) {
      try {
        return (
          start: DateTime.utc(y, m0, d0),
          end: DateTime.utc(y, m1, d1, 23, 59, 59),
        );
      } catch (_) {}
    }
  }
  final same = _stremioSameMonthRangeRe.firstMatch(title);
  if (same != null) {
    final y = int.tryParse(same.group(4)!);
    final d0 = int.tryParse(same.group(1)!);
    final d1 = int.tryParse(same.group(2)!);
    final m = _stremioMonthNum(same.group(3));
    if (y != null && d0 != null && d1 != null && m != null) {
      try {
        return (
          start: DateTime.utc(y, m, d0),
          end: DateTime.utc(y, m, d1, 23, 59, 59),
        );
      } catch (_) {}
    }
  }
  final single = _stremioSingleDayRe.firstMatch(title);
  if (single != null) {
    final y = int.tryParse(single.group(3)!);
    final d = int.tryParse(single.group(1)!);
    final m = _stremioMonthNum(single.group(2));
    if (y != null && d != null && m != null) {
      try {
        final day = DateTime.utc(y, m, d);
        return (start: day, end: DateTime.utc(y, m, d, 23, 59, 59));
      } catch (_) {}
    }
  }
  return null;
}

/// Multi-day title window still covers today (Flix Solheim Cup / US Open).
bool stremioTitleEventIsOngoing(String title, {DateTime? now}) {
  final range = stremioParseTitleDateRange(title);
  if (range == null) return false;
  // Single-day rows are not "ongoing tournaments".
  final sameDay = range.start.year == range.end.year &&
      range.start.month == range.end.month &&
      range.start.day == range.end.day;
  if (sameDay) return false;
  final n = (now ?? DateTime.now()).toUtc();
  return !n.isBefore(range.start) && !n.isAfter(range.end);
}

/// Kickoff from `Time: HH:MM` in description + a calendar date in the title
/// (including ranges like `7 – 13 September 2026`).
///
/// Ongoing multi-day events use **today + Time** so schedule filters keep them.
/// Expired ranges return 0.
int stremioKickoffMsFromTitleAndTime({
  required String title,
  required String description,
  DateTime? now,
}) {
  final timeMatch = RegExp(
    r'Time:\s*(\d{1,2}):(\d{2})',
    caseSensitive: false,
  ).firstMatch(description);
  if (timeMatch == null) return 0;
  final hour = int.tryParse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2)!);
  if (hour == null || minute == null) return 0;

  final n = (now ?? DateTime.now()).toUtc();
  final range = stremioParseTitleDateRange(title);
  if (range == null) {
    // Clock only (Flix camera feeds / TV) — assume today UTC.
    try {
      return DateTime.utc(n.year, n.month, n.day, hour, minute)
          .millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  final startKick = DateTime.utc(
    range.start.year,
    range.start.month,
    range.start.day,
    hour,
    minute,
  );
  if (n.isBefore(range.start)) {
    return startKick.millisecondsSinceEpoch;
  }
  if (n.isAfter(range.end)) {
    return 0;
  }
  // Inside multi-day / today window.
  try {
    return DateTime.utc(n.year, n.month, n.day, hour, minute)
        .millisecondsSinceEpoch;
  } catch (_) {
    return startKick.millisecondsSinceEpoch;
  }
}

/// Highfly Sports Streams style: `10 Sep 2026 · 10:00 UTC`.
final _stremioReleaseInfoKickoffRe = RegExp(
  r'^(\d{1,2})\s+'
  r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+'
  r'(\d{4})\s*[·•\-\u2013|]\s*'
  r'(\d{1,2}):(\d{2})(?:\s*UTC)?',
  caseSensitive: false,
);

/// Parse Stremio `releaseInfo` kickoff (ISO or Highfly day·time UTC).
int stremioKickoffMsFromReleaseInfo(String releaseInfo) {
  final s = releaseInfo.trim();
  if (s.isEmpty) return 0;
  // Bare LIVE / labels are not dates.
  if (RegExp(r'^(live|live\s*now|live\s*tv)$', caseSensitive: false)
      .hasMatch(s)) {
    return 0;
  }
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.millisecondsSinceEpoch;

  final m = _stremioReleaseInfoKickoffRe.firstMatch(s);
  if (m == null) return 0;
  final month = _stremioMonthNum(m.group(2));
  final day = int.tryParse(m.group(1)!);
  final year = int.tryParse(m.group(3)!);
  final hour = int.tryParse(m.group(4)!);
  final minute = int.tryParse(m.group(5)!);
  if (month == null ||
      day == null ||
      year == null ||
      hour == null ||
      minute == null) {
    return 0;
  }
  try {
    return DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

/// True when kickoff is in the live window (started, not older than 6h).
bool stremioKickoffIsAiringNow(int dateMs, {DateTime? now}) {
  if (dateMs <= 0) return false;
  final n = now ?? DateTime.now();
  final start = DateTime.fromMillisecondsSinceEpoch(dateMs);
  return !start.isAfter(n) &&
      !start.isBefore(n.subtract(const Duration(hours: 6)));
}
