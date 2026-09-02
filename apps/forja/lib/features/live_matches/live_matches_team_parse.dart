/// Split a Live Matches catalog title into `(home, away)`.
///
/// - `A vs B` / `A v B` / `A versus B` → home=A, away=B
/// - `A at B` / `A @ B` → away=A, home=B (US sports: visitor at home)
///
/// PPV-style catalogs often use `away at home`; Streamed-style use
/// `home vs away` — same fixture, reversed surface names.
(String, String) parseLiveMatchTeamsFromTitle(String raw) {
  final title = raw
      .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isEmpty) return ('', '');

  final at = RegExp(r'\s+(?:at|@)\s+', caseSensitive: false).firstMatch(title);
  if (at != null) {
    final left = title.substring(0, at.start).trim();
    final right = title
        .substring(at.end)
        .split(RegExp(r'\s+[-–—|/]\s+'))
        .first
        .trim();
    return (right, left);
  }

  final vs = RegExp(r'\s+(?:vs\.?|v|versus)\s+', caseSensitive: false)
      .firstMatch(title);
  if (vs != null) {
    final left = title.substring(0, vs.start).trim();
    final right = title
        .substring(vs.end)
        .split(RegExp(r'\s+[-–—|/]\s+'))
        .first
        .trim();
    return (left, right);
  }

  return ('', '');
}

/// Prefer structured teams; fill gaps from [title] (`at` / `vs` aware).
(String, String) resolveLiveMatchTeams({
  String? homeTeam,
  String? awayTeam,
  required String title,
}) {
  var home = (homeTeam ?? '').trim();
  var away = (awayTeam ?? '').trim();
  if (home.isEmpty || away.isEmpty) {
    final parsed = parseLiveMatchTeamsFromTitle(title);
    if (home.isEmpty) home = parsed.$1;
    if (away.isEmpty) away = parsed.$2;
  }
  return (home, away);
}

const _genericTeamSuffixes = {
  'city',
  'united',
  'town',
  'rovers',
  'county',
  'athletic',
  'wanderers',
  'albion',
  'villa',
  'forest',
  'palace',
  'north',
  'south',
  'west',
  'east',
  'sport',
  'sports',
  'fc',
  'sc',
  'afc',
  'cf',
  'cd',
  'real',
  'inter',
  'sporting',
};

/// Distinctive nickname for IPTV matcher — never bare suffixes like "City".
String sportNickFromTeam(String team) {
  final bits = team.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (bits.isEmpty) return '';
  for (var i = bits.length - 1; i >= 0; i--) {
    final w = bits[i].toLowerCase();
    if (w.length >= 3 && !_genericTeamSuffixes.contains(w)) {
      return bits[i];
    }
  }
  return bits.first;
}
