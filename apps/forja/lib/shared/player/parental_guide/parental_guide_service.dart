import 'dart:convert';

import 'package:http/http.dart' as http;

const _kBaseUrl = 'https://api.tiffara.com';
final _imdbIdPattern = RegExp(r'tt\d+');

class ParentalWarning {
  const ParentalWarning({required this.label, required this.severity});

  final String label;
  final String severity;
}

class ParentalGuideResult {
  const ParentalGuideResult({
    this.nudity,
    this.violence,
    this.profanity,
    this.alcohol,
    this.frightening,
  });

  final String? nudity;
  final String? violence;
  final String? profanity;
  final String? alcohol;
  final String? frightening;

  bool get isEmpty =>
      nudity == null &&
      violence == null &&
      profanity == null &&
      alcohol == null &&
      frightening == null;
}

class ParentalGuideService {
  ParentalGuideService._();
  static final ParentalGuideService instance = ParentalGuideService._();

  final Map<String, ParentalGuideResult?> _cache = {};
  final Map<String, Future<ParentalGuideResult?>> _inflight = {};

  Future<ParentalGuideResult?> getParentalGuide(String? imdbId) {
    final id = extractParentalGuideImdbId(imdbId);
    if (id == null) return Future.value(null);
    if (_cache.containsKey(id)) return Future.value(_cache[id]);
    return _inflight.putIfAbsent(id, () async {
      try {
        final result = await _fetch(id);
        _cache[id] = result;
        return result;
      } finally {
        _inflight.remove(id);
      }
    });
  }

  Future<ParentalGuideResult?> _fetch(String imdbId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/titles/$imdbId/parentsGuide'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode > 299 || res.body.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final categories = decoded['parentsGuide'];
      if (categories is! List || categories.isEmpty) return null;
      return mapParentalGuideCategories(categories);
    } catch (_) {
      return null;
    }
  }
}

String? extractParentalGuideImdbId(String? value) {
  if (value == null || value.isEmpty) return null;
  final match = _imdbIdPattern.firstMatch(value);
  final id = match?.group(0);
  if (id == null || !id.startsWith('tt')) return null;
  return id;
}

ParentalGuideResult mapParentalGuideCategories(List<dynamic> categories) {
  final map = <String, Map<String, dynamic>>{};
  for (final raw in categories) {
    if (raw is! Map) continue;
    final category = raw['category']?.toString().toUpperCase() ?? '';
    if (category.isEmpty) continue;
    map[category] = Map<String, dynamic>.from(raw);
  }
  return ParentalGuideResult(
    nudity: resolveParentalGuideSeverity(map['SEXUAL_CONTENT']),
    violence: resolveParentalGuideSeverity(map['VIOLENCE']),
    profanity: resolveParentalGuideSeverity(map['PROFANITY']),
    alcohol: resolveParentalGuideSeverity(map['ALCOHOL_DRUGS']),
    frightening: resolveParentalGuideSeverity(map['FRIGHTENING_INTENSE_SCENES']),
  );
}

String? resolveParentalGuideSeverity(Map<String, dynamic>? category) {
  final breakdowns = category?['severityBreakdowns'];
  if (breakdowns is! List) return null;

  Map<String, dynamic>? dominant;
  var dominantVotes = -1;
  var noneVotes = 0;
  for (final raw in breakdowns) {
    if (raw is! Map) continue;
    final level = raw['severityLevel']?.toString().toLowerCase() ?? '';
    final votes = (raw['voteCount'] as num?)?.toInt() ?? 0;
    if (level == 'none') {
      noneVotes = votes;
      continue;
    }
    if (votes > dominantVotes) {
      dominantVotes = votes;
      dominant = Map<String, dynamic>.from(raw);
    }
  }
  if (dominant == null || dominantVotes <= noneVotes) return null;
  return dominant['severityLevel']?.toString().toLowerCase();
}

List<ParentalWarning> buildParentalWarnings(ParentalGuideResult guide) {
  const severityOrder = {'severe': 0, 'moderate': 1, 'mild': 2};
  const labels = {
    'nudity': 'Nudity',
    'violence': 'Violence',
    'profanity': 'Profanity',
    'alcohol': 'Alcohol/Drugs',
    'frightening': 'Frightening',
  };
  final rows = <(String, String)>[
    if (guide.nudity != null) ('nudity', guide.nudity!),
    if (guide.violence != null) ('violence', guide.violence!),
    if (guide.profanity != null) ('profanity', guide.profanity!),
    if (guide.alcohol != null) ('alcohol', guide.alcohol!),
    if (guide.frightening != null) ('frightening', guide.frightening!),
  ];
  rows.sort(
    (a, b) => (severityOrder[a.$2] ?? 3).compareTo(severityOrder[b.$2] ?? 3),
  );
  return rows
      .take(5)
      .map(
        (row) => ParentalWarning(
          label: labels[row.$1] ?? row.$1,
          severity: row.$2,
        ),
      )
      .toList();
}
