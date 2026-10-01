/// Clean portal/release-group junk from media titles for subtitle search.
class CleanedMediaTitle {
  const CleanedMediaTitle({
    required this.title,
    this.year,
    this.season,
    this.episode,
  });

  final String title;
  final int? year;
  final int? season;
  final int? episode;

  bool get isEmpty => title.trim().isEmpty;
}

/// Strips `EN-` / `NETFLIX-` / quality tags, pulls year + SxxExx when present.
CleanedMediaTitle cleanMediaTitle(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return const CleanedMediaTitle(title: '');

  // Fullwidth / broken-bar / box-drawing pipes → ASCII `|`.
  s = s.replaceAll(RegExp(r'[\uFF5C\u00A6\u2502\u2503\u01C0\u2223]'), '|');

  s = s.replaceAll(RegExp(r'[_\.]+'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  int? season;
  int? episode;
  final se = RegExp(
    r'\b[Ss](\d{1,2})\s*[Ee](\d{1,3})\b|\b(\d{1,2})\s*[xX]\s*(\d{1,3})\b',
  ).firstMatch(s);
  if (se != null) {
    season = int.tryParse(se.group(1) ?? se.group(3) ?? '');
    episode = int.tryParse(se.group(2) ?? se.group(4) ?? '');
    s = s.replaceRange(se.start, se.end, ' ');
  }

  int? year;
  final yearMatch = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(s);
  if (yearMatch != null) {
    year = int.tryParse(yearMatch.group(1)!);
    s = s.replaceRange(yearMatch.start, yearMatch.end, ' ');
  }

  // Leading `|EN|` / `|FR|` pipe tags (common portal prefixes).
  for (var i = 0; i < 4; i++) {
    final next = s.replaceFirst(
      RegExp(
        r'^\|?\s*(?:'
        r'EN|FR|AR|ES|DE|IT|PT|NL|TR|PL|RU|MULTI|VO|VF|VOSTFR|VOST|'
        r'NETFLIX|NF|AMAZON|AMZN|PRIME|DISNEY(?:\+)?|HULU|HBO|MAX|APPLE|ATVP|'
        r'DC|DV|WEB|WEB[- ]?DL|WEBRip'
        r')\s*\|+\s*',
        caseSensitive: false,
      ),
      '',
    );
    if (next == s) break;
    s = next;
  }

  // Empty pipe slots: `| | Title`, `|| Title`, leading `| Title`.
  for (var i = 0; i < 6; i++) {
    final emptied = s.replaceFirst(RegExp(r'^(?:\s*\|)+\s*'), '');
    if (emptied == s) break;
    s = emptied;
  }

  // Leading platform / lang tags: EN-, FR-, NETFLIX-, Disney+-, etc.
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'EN|FR|AR|ES|DE|IT|PT|NL|TR|PL|RU|MULTI|VO|VF|VOSTFR|VOST|'
      r'NETFLIX|NF|AMAZON|AMZN|PRIME|DISNEY(?:\+)?|HULU|HBO|MAX|APPLE|ATVP|'
      r'DC|DV|WEB|WEB[- ]?DL|WEBRip'
      r')\s*[-:]\s*',
      caseSensitive: false,
    ),
    '',
  );
  // Repeat once — common `EN-NETFLIX-Title`.
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'EN|FR|AR|ES|DE|IT|PT|NL|TR|PL|RU|MULTI|VO|VF|VOSTFR|VOST|'
      r'NETFLIX|NF|AMAZON|AMZN|PRIME|DISNEY(?:\+)?|HULU|HBO|MAX|APPLE|ATVP'
      r')\s*[-:]\s*',
      caseSensitive: false,
    ),
    '',
  );

  // Bracket / paren junk: [1080p], (MULTI), {Web-DL}
  s = s.replaceAll(RegExp(r'[\[\(\{][^\]\)\}]{0,40}[\]\)\}]'), ' ');

  // Trailing / mid quality + release tokens.
  const junk = r'(?:'
      r'1080p|720p|480p|2160p|4K|UHD|HDR10?\+?|DV|Dolby(?:\s*Vision)?|'
      r'x264|x265|h\.?264|h\.?265|HEVC|AVC|AAC|AC3|DTS|Atmos|'
      r'BluRay|BDRip|BRRip|HDRip|DVDRip|HDTV|WEB[- ]?DL|WEBRip|WEB|'
      r'REPACK|PROPER|INTERNAL|LIMITED|EXTENDED|UNRATED|IMAX|'
      r'MULTI|DUAL|SUBBED|DUBBED|VOSTFR|VOST|VF|VO|'
      r'COMPLETE|SEASON|Saison'
      r')';
  s = s.replaceAll(
    RegExp('\\b$junk\\b', caseSensitive: false),
    ' ',
  );

  s = s.replaceAll(RegExp(r'[-|~/\\]+'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceAll(RegExp(r'^[\-\s:]+|[\-\s:]+$'), '').trim();

  return CleanedMediaTitle(
    title: s,
    year: year,
    season: season,
    episode: episode,
  );
}
