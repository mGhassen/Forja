// Fixture cache keys for IPTV Live TV channel search (no live-sports catalog DTO).

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

String matchTextKey(String raw) {
  final folded = foldLiveMatchLatin(raw)
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  return folded.replaceAll(RegExp(r'\s+'), ' ');
}

String? matchTeamPairKey(String home, String away) {
  final h = matchTextKey(home);
  final a = matchTextKey(away);
  if (h.isEmpty || a.isEmpty) return null;
  final parts = [h, a]..sort();
  return '${parts[0]}|${parts[1]}';
}
