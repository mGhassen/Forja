/// Normalize titles for Open-with hub search ranking.
String listOpenTitleKey(String raw) {
  var s = raw.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'[\(\[\{]\s*\d{4}\s*[\)\]\}]'), ' ');
  s = s.replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceFirst(RegExp(r'^(the|a|an)\s+'), '');
  return s;
}

/// Year from `2024`, `(2024)`, or `2024-01-01` style release strings.
int? listOpenParseYear(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'\b(19|20)\d{2}\b').firstMatch(s);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

/// Higher = better match against [query]. Exact normalized name wins.
int listOpenTitleScore(
  String query,
  String candidate, {
  int? queryYear,
  int? candidateYear,
}) {
  final q = listOpenTitleKey(query);
  final c = listOpenTitleKey(candidate);
  if (q.isEmpty || c.isEmpty) return 0;

  var score = 0;
  if (q == c) {
    score = 1000;
  } else {
    final qt = q.split(' ').where((t) => t.length > 1).toSet();
    final ct = c.split(' ').where((t) => t.length > 1).toSet();
    if (qt.isNotEmpty && ct.isNotEmpty && qt.length == ct.length && qt.containsAll(ct)) {
      score = 900; // same tokens, different order
    } else if (c.startsWith(q) || q.startsWith(c)) {
      score = 800;
    } else if (qt.isNotEmpty && qt.every(ct.contains)) {
      score = 650; // all query tokens present
    } else if (c.contains(q) || q.contains(c)) {
      score = 500;
    } else if (qt.isNotEmpty && ct.isNotEmpty) {
      final overlap = qt.intersection(ct).length;
      if (overlap == 0) return 0;
      score = overlap * 80;
    } else {
      return 0;
    }
  }

  if (queryYear != null && candidateYear != null) {
    if (queryYear == candidateYear) {
      score += 120;
    } else {
      score -= 40;
    }
  }
  return score;
}

/// Sort hub search hits so the best title match is first. Drops zero-score
/// noise when at least one scored hit exists.
List<T> listOpenRankByTitle<T>(
  String query,
  List<T> hits, {
  required String Function(T) nameOf,
  String Function(T)? releaseOf,
  int? queryYear,
}) {
  if (hits.length <= 1) return List<T>.from(hits);
  final qYear = queryYear ?? listOpenParseYear(query);
  final scored = <({T hit, int score})>[];
  for (final hit in hits) {
    final year = listOpenParseYear(releaseOf?.call(hit));
    final score = listOpenTitleScore(
      query,
      nameOf(hit),
      queryYear: qYear,
      candidateYear: year,
    );
    scored.add((hit: hit, score: score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  final positive = scored.where((e) => e.score > 0).map((e) => e.hit).toList();
  if (positive.isNotEmpty) return positive;
  return scored.map((e) => e.hit).toList();
}

bool listOpenIsStrongTitleMatch(String query, String candidate, {int? queryYear, int? candidateYear}) {
  return listOpenTitleScore(
        query,
        candidate,
        queryYear: queryYear,
        candidateYear: candidateYear,
      ) >=
      900;
}
