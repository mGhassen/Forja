/// Fold Latin accents so `León` matches `Leon` in event keys.
String foldLiveMatchLatin(String raw) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüñçýÿø';
  const to = 'aaaaaaeeeeiiiiooooouuuuncyyo';
  final buf = StringBuffer();
  for (final unit in raw.toLowerCase().codeUnits) {
    final ch = String.fromCharCode(unit);
    final i = from.indexOf(ch);
    if (i >= 0) {
      buf.write(to[i]);
    } else if (ch == 'æ') {
      buf.write('ae');
    } else if (ch == 'œ') {
      buf.write('oe');
    } else {
      buf.write(ch);
    }
  }
  return buf.toString();
}

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
  'club',
  'deportivo',
  'atletico',
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

/// Ordered tokens for soft team equality — keeps City/United/State (unlike IPTV keys).
List<String> liveTeamMatchTokens(String raw) {
  var value = foldLiveMatchLatin(raw.toLowerCase());
  value = value
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  if (value.isEmpty) return const [];
  return value
      .split(RegExp(r'\s+'))
      .where(
        (token) =>
            token.isNotEmpty &&
            token != 'fc' &&
            token != 'sc' &&
            token != 'afc' &&
            token != 'cf' &&
            token != 'the',
      )
      .toList();
}

/// School / campus qualifiers — trailing extras that mean a *different* team.
const liveTeamSchoolQualifiers = {
  'state',
  'university',
  'univ',
  'college',
  'tech',
  'am',
  'a',
  'm',
};

/// Soft team name match: exact tokens, or shorter is an ordered prefix of longer.
///
/// Allows `Colorado` ↔ `Colorado Buffaloes` and `Georgia Tech` ↔
/// `Georgia Tech Yellow Jackets`, but rejects `Florida` ↔ `Florida State`
/// and `Manchester City` ↔ `Manchester United`.
bool liveTeamNamesSoftEqual(String a, String b) {
  final ta = liveTeamMatchTokens(a);
  final tb = liveTeamMatchTokens(b);
  if (ta.isEmpty || tb.isEmpty) return false;
  if (ta.length == tb.length) {
    for (var i = 0; i < ta.length; i++) {
      if (ta[i] != tb[i]) return false;
    }
    return true;
  }
  final short = ta.length < tb.length ? ta : tb;
  final long = ta.length < tb.length ? tb : ta;
  for (var i = 0; i < short.length; i++) {
    if (short[i] != long[i]) return false;
  }
  final trailing = long.sublist(short.length);
  if (trailing.isEmpty) return true;
  // Multi-token short (Georgia Tech) — trailing nicknames are fine.
  if (short.length >= 2) {
    return trailing.every((t) => t.length >= 2);
  }
  // Single-token short (Colorado / Florida): allow mascot suffixes only —
  // reject school qualifiers that mint a different program.
  if (trailing.any(liveTeamSchoolQualifiers.contains)) return false;
  return trailing.every((t) => t.length >= 3);
}

/// Order-independent fixture pair: (homeA,awayA) soft-matches (homeB,awayB).
bool liveTeamPairSoftEqual(
  String homeA,
  String awayA,
  String homeB,
  String awayB,
) {
  if (homeA.isEmpty || awayA.isEmpty || homeB.isEmpty || awayB.isEmpty) {
    return false;
  }
  return (liveTeamNamesSoftEqual(homeA, homeB) &&
          liveTeamNamesSoftEqual(awayA, awayB)) ||
      (liveTeamNamesSoftEqual(homeA, awayB) &&
          liveTeamNamesSoftEqual(awayA, homeB));
}
