/// Generic Stremio sport/live meta signals for Live Sports schedule filters.
///
/// Shape-based only — no addon ids, hostnames, or pack names. Any live addon
/// that uses common Stremio fields (`releaseInfo`, description, genres, poster
/// badge query, `Time:` + calendar date) gets the same treatment.

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

/// Kickoff from `Time: HH:MM` in description + a calendar date in the title
/// (including ranges like `7 – 13 September 2026` → first day).
int stremioKickoffMsFromTitleAndTime({
  required String title,
  required String description,
}) {
  final timeMatch = RegExp(
    r'Time:\s*(\d{1,2}):(\d{2})',
    caseSensitive: false,
  ).firstMatch(description);
  if (timeMatch == null) return 0;
  final hour = int.tryParse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2)!);
  if (hour == null || minute == null) return 0;

  final dateMatch = _stremioCalendarDateRe.firstMatch(title);
  if (dateMatch == null) return 0;
  const months = {
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
  final month = months[dateMatch.group(2)!.toLowerCase().substring(0, 3)];
  if (month == null) return 0;
  final day = int.tryParse(dateMatch.group(1)!);
  final year = int.tryParse(dateMatch.group(3)!);
  if (day == null || year == null) return 0;
  try {
    return DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}
