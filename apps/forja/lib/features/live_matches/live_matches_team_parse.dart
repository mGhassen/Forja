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
