/// Person hit from TMDB `search/person` (structured Search).
class TmdbPersonHit {
  const TmdbPersonHit({
    required this.id,
    required this.name,
    required this.popularity,
  });

  final int id;
  final String name;
  final double popularity;
}

/// Structured parse of a Search-box query (year / range / genre + remainder).
class ParsedSearchQuery {
  const ParsedSearchQuery({
    required this.raw,
    required this.remainder,
    this.year,
    this.yearStart,
    this.yearEnd,
    this.movieGenreIds = const [],
    this.tvGenreIds = const [],
    this.matchedGenreLabel,
    this.mediaType,
    this.minScore,
    this.maxScore,
    this.originCountry,
  });

  final String raw;
  /// Text left after stripping year/range / score / type / country / genre tokens.
  final String remainder;
  final int? year;
  final int? yearStart;
  final int? yearEnd;
  final List<int> movieGenreIds;
  final List<int> tvGenreIds;
  final String? matchedGenreLabel;
  /// `movie` | `tv` when the query asked for films/series only.
  final String? mediaType;
  final double? minScore;
  final double? maxScore;
  /// ISO 3166-1 alpha-2 when a country token was matched.
  final String? originCountry;

  bool get hasYear =>
      year != null || (yearStart != null && yearEnd != null);

  bool get hasGenre =>
      movieGenreIds.isNotEmpty || tvGenreIds.isNotEmpty;

  bool get hasScore => minScore != null || maxScore != null;

  bool get hasMediaType => mediaType != null;

  bool get hasOriginCountry => originCountry != null;

  bool get hasStructuredFilters =>
      hasYear || hasGenre || hasScore || hasMediaType || hasOriginCountry;

  bool get hasPersonCandidate => remainder.trim().length >= 2;

  /// Inclusive year bounds for filtering release dates.
  (int, int)? get yearBounds {
    if (yearStart != null && yearEnd != null) {
      final a = yearStart! <= yearEnd! ? yearStart! : yearEnd!;
      final b = yearStart! <= yearEnd! ? yearEnd! : yearStart!;
      return (a, b);
    }
    if (year != null) return (year!, year!);
    return null;
  }
}

class _GenreAlias {
  const _GenreAlias({
    required this.aliases,
    required this.label,
    required this.movieIds,
    required this.tvIds,
  });

  final List<String> aliases;
  final String label;
  final List<int> movieIds;
  final List<int> tvIds;
}

/// TMDB genre ids + common aliases. TV has no Horror — movies only for that.
const _genreAliases = <_GenreAlias>[
  _GenreAlias(
    aliases: ['science fiction', 'sci-fi', 'scifi', 'sci fi'],
    label: 'Science Fiction',
    movieIds: [878],
    tvIds: [10765],
  ),
  _GenreAlias(
    aliases: ['action & adventure', 'action and adventure'],
    label: 'Action & Adventure',
    movieIds: [28, 12],
    tvIds: [10759],
  ),
  _GenreAlias(
    aliases: ['tv movie', 'tv-movie'],
    label: 'TV Movie',
    movieIds: [10770],
    tvIds: [],
  ),
  _GenreAlias(
    aliases: ['war & politics', 'war and politics'],
    label: 'War & Politics',
    movieIds: [10752],
    tvIds: [10768],
  ),
  _GenreAlias(
    aliases: ['action'],
    label: 'Action',
    movieIds: [28],
    tvIds: [10759],
  ),
  _GenreAlias(
    aliases: ['adventure'],
    label: 'Adventure',
    movieIds: [12],
    tvIds: [10759],
  ),
  _GenreAlias(
    aliases: ['animation', 'anime'],
    label: 'Animation',
    movieIds: [16],
    tvIds: [16],
  ),
  _GenreAlias(
    aliases: ['comedy'],
    label: 'Comedy',
    movieIds: [35],
    tvIds: [35],
  ),
  _GenreAlias(
    aliases: ['crime'],
    label: 'Crime',
    movieIds: [80],
    tvIds: [80],
  ),
  _GenreAlias(
    aliases: ['documentary', 'docs'],
    label: 'Documentary',
    movieIds: [99],
    tvIds: [99],
  ),
  _GenreAlias(
    aliases: ['drama'],
    label: 'Drama',
    movieIds: [18],
    tvIds: [18],
  ),
  _GenreAlias(
    aliases: ['family'],
    label: 'Family',
    movieIds: [10751],
    tvIds: [10751],
  ),
  _GenreAlias(
    aliases: ['fantasy'],
    label: 'Fantasy',
    movieIds: [14],
    tvIds: [10765],
  ),
  _GenreAlias(
    aliases: ['history'],
    label: 'History',
    movieIds: [36],
    tvIds: [36],
  ),
  _GenreAlias(
    aliases: ['horror'],
    label: 'Horror',
    movieIds: [27],
    // TMDB has no dedicated TV Horror genre; many series still carry 27.
    tvIds: [27],
  ),
  _GenreAlias(
    aliases: ['music', 'musical'],
    label: 'Music',
    movieIds: [10402],
    tvIds: [10402],
  ),
  _GenreAlias(
    aliases: ['mystery'],
    label: 'Mystery',
    movieIds: [9648],
    tvIds: [9648],
  ),
  _GenreAlias(
    aliases: ['romance', 'romantic'],
    label: 'Romance',
    movieIds: [10749],
    tvIds: [10749],
  ),
  _GenreAlias(
    aliases: ['thriller'],
    label: 'Thriller',
    movieIds: [53],
    tvIds: [53],
  ),
  _GenreAlias(
    aliases: ['war'],
    label: 'War',
    movieIds: [10752],
    tvIds: [10768],
  ),
  _GenreAlias(
    aliases: ['western'],
    label: 'Western',
    movieIds: [37],
    tvIds: [37],
  ),
  _GenreAlias(
    aliases: ['kids', 'children'],
    label: 'Kids',
    movieIds: [10751],
    tvIds: [10762],
  ),
];

final _yearRangeRe = RegExp(
  r'\b((?:19|20)\d{2})\s*[-–—]\s*((?:19|20)\d{2})\b',
);
final _yearRe = RegExp(r'\b((?:19|20)\d{2})\b');

/// Parse [raw] into year/range, optional genre, and remainder text.
final _scoreOpRe = RegExp(
  r'(?:^|\s)(>=|<=|>|<)\s*(\d(?:\.\d)?)(?=\s|$)',
);
final _scoreRangeRe = RegExp(
  r'(?:^|\s)(\d(?:\.\d)?)\s*[-–—]\s*(\d(?:\.\d)?)(?=\s|$)',
);
final _mediaTypeRe = RegExp(
  r'(?:^|\s)(films?|movies?|series|shows?|tv)(?=\s|$)',
  caseSensitive: false,
);


class _CountryAlias {
  const _CountryAlias({required this.aliases, required this.code, required this.label});
  final List<String> aliases;
  final String code;
  final String label;
}

const _countryAliases = <_CountryAlias>[
  _CountryAlias(aliases: ['united states', 'usa', 'u.s.', 'u.s.a.', 'america'], code: 'US', label: 'USA'),
  _CountryAlias(aliases: ['united kingdom', 'uk', 'u.k.', 'britain', 'england'], code: 'GB', label: 'UK'),
  _CountryAlias(aliases: ['france', 'french'], code: 'FR', label: 'France'),
  _CountryAlias(aliases: ['germany', 'german'], code: 'DE', label: 'Germany'),
  _CountryAlias(aliases: ['japan', 'japanese'], code: 'JP', label: 'Japan'),
  _CountryAlias(aliases: ['south korea', 'korea', 'korean'], code: 'KR', label: 'Korea'),
  _CountryAlias(aliases: ['india', 'indian', 'bollywood'], code: 'IN', label: 'India'),
  _CountryAlias(aliases: ['italy', 'italian'], code: 'IT', label: 'Italy'),
  _CountryAlias(aliases: ['spain', 'spanish'], code: 'ES', label: 'Spain'),
  _CountryAlias(aliases: ['canada', 'canadian'], code: 'CA', label: 'Canada'),
  _CountryAlias(aliases: ['australia', 'australian'], code: 'AU', label: 'Australia'),
  _CountryAlias(aliases: ['china', 'chinese'], code: 'CN', label: 'China'),
  _CountryAlias(aliases: ['brazil', 'brazilian'], code: 'BR', label: 'Brazil'),
  _CountryAlias(aliases: ['mexico', 'mexican'], code: 'MX', label: 'Mexico'),
  _CountryAlias(aliases: ['sweden', 'swedish'], code: 'SE', label: 'Sweden'),
  _CountryAlias(aliases: ['norway', 'norwegian'], code: 'NO', label: 'Norway'),
  _CountryAlias(aliases: ['denmark', 'danish'], code: 'DK', label: 'Denmark'),
  _CountryAlias(aliases: ['turkey', 'turkish'], code: 'TR', label: 'Turkey'),
  _CountryAlias(aliases: ['hong kong'], code: 'HK', label: 'Hong Kong'),
  _CountryAlias(aliases: ['taiwan', 'taiwanese'], code: 'TW', label: 'Taiwan'),
  _CountryAlias(aliases: ['thailand', 'thai'], code: 'TH', label: 'Thailand'),
];

ParsedSearchQuery parseSearchQuery(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return ParsedSearchQuery(raw: raw, remainder: '');
  }

  var working = trimmed;
  int? year;
  int? yearStart;
  int? yearEnd;

  final range = _yearRangeRe.firstMatch(working);
  if (range != null) {
    yearStart = int.tryParse(range.group(1)!);
    yearEnd = int.tryParse(range.group(2)!);
    working = working.replaceRange(range.start, range.end, ' ').trim();
  } else {
    final single = _yearRe.firstMatch(working);
    if (single != null) {
      year = int.tryParse(single.group(1)!);
      working = working.replaceRange(single.start, single.end, ' ').trim();
    }
  }

  working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

  double? minScore;
  double? maxScore;
  // Collect ops on a padded copy, then strip from [working].
  final padded = ' $working ';
  for (final m in _scoreOpRe.allMatches(padded)) {
    final op = m.group(1)!;
    final v = double.tryParse(m.group(2)!);
    if (v == null) continue;
    // TMDB only exposes gte/lte — treat > / < as inclusive bounds.
    if (op == '>' || op == '>=') {
      minScore = minScore == null ? v : (v > minScore! ? v : minScore);
    } else {
      maxScore = maxScore == null ? v : (v < maxScore! ? v : maxScore);
    }
  }
  working = working.replaceAll(_scoreOpRe, ' ');
  working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Score range like 8-9 (both ends ≤10) — not a calendar year range.
  final scoreRange = _scoreRangeRe.firstMatch(' $working ');
  if (scoreRange != null) {
    final a = double.tryParse(scoreRange.group(1)!);
    final b = double.tryParse(scoreRange.group(2)!);
    if (a != null && b != null && a <= 10 && b <= 10) {
      final lo = a <= b ? a : b;
      final hi = a <= b ? b : a;
      minScore = minScore == null ? lo : (minScore! > lo ? minScore : lo);
      maxScore = maxScore == null ? hi : (maxScore! < hi ? maxScore : hi);
      working = (' $working ').replaceFirst(_scoreRangeRe, ' ');
    }
  }
  working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

  String? mediaType;
  final mediaMatch = _mediaTypeRe.firstMatch(' $working ');
  if (mediaMatch != null) {
    final tok = mediaMatch.group(1)!.toLowerCase();
    if (tok.startsWith('film') || tok.startsWith('movie')) {
      mediaType = 'movie';
    } else {
      mediaType = 'tv';
    }
    working = (' $working ').replaceFirst(_mediaTypeRe, ' ');
  }
  working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

  String? originCountry;
  if (working.isNotEmpty) {
    final lower = working.toLowerCase();
    _CountryAlias? best;
    var bestLen = 0;
    for (final c in _countryAliases) {
      for (final alias in c.aliases) {
        if (alias.length < bestLen) continue;
        if (!_containsGenreToken(lower, alias)) continue;
        best = c;
        bestLen = alias.length;
      }
    }
    if (best != null) {
      originCountry = best.code;
      working = _stripGenreToken(working, best.aliases);
    }
  }
  working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

  List<int> movieGenreIds = const [];
  List<int> tvGenreIds = const [];
  String? genreLabel;

  if (working.isNotEmpty) {
    final lower = working.toLowerCase();
    _GenreAlias? best;
    var bestAliasLen = 0;
    for (final g in _genreAliases) {
      for (final alias in g.aliases) {
        if (alias.length < bestAliasLen) continue;
        if (!_containsGenreToken(lower, alias)) continue;
        best = g;
        bestAliasLen = alias.length;
      }
    }
    if (best != null) {
      movieGenreIds = best.movieIds;
      tvGenreIds = best.tvIds;
      genreLabel = best.label;
      working = _stripGenreToken(working, best.aliases);
    }
  }

  return ParsedSearchQuery(
    raw: raw,
    remainder: working.replaceAll(RegExp(r'\s+'), ' ').trim(),
    year: year,
    yearStart: yearStart,
    yearEnd: yearEnd,
    movieGenreIds: movieGenreIds,
    tvGenreIds: tvGenreIds,
    matchedGenreLabel: genreLabel,
    mediaType: mediaType,
    minScore: minScore,
    maxScore: maxScore,
    originCountry: originCountry,
  );
}

bool _containsGenreToken(String lowerHaystack, String alias) {
  if (alias.contains(' ')) {
    return RegExp(
      r'(^|\s)' + RegExp.escape(alias) + r'(\s|$)',
    ).hasMatch(lowerHaystack);
  }
  final parts = lowerHaystack.split(RegExp(r'\s+'));
  return parts.contains(alias);
}

String _stripGenreToken(String working, List<String> aliases) {
  var out = working;
  final sorted = [...aliases]..sort((a, b) => b.length.compareTo(a.length));
  for (final alias in sorted) {
    final re = RegExp(
      r'(^|\s)' + RegExp.escape(alias) + r'(\s|$)',
      caseSensitive: false,
    );
    final m = re.firstMatch(out);
    if (m == null) continue;
    out = out.replaceRange(m.start, m.end, ' ');
    break;
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True when [releaseDate] (`YYYY-MM-DD` or `YYYY`) falls in [bounds].
bool releaseDateInYearBounds(String releaseDate, (int, int) bounds) {
  if (releaseDate.length < 4) return false;
  final y = int.tryParse(releaseDate.substring(0, 4));
  if (y == null) return false;
  return y >= bounds.$1 && y <= bounds.$2;
}
