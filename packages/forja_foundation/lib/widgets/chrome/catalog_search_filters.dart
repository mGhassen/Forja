import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

enum SearchMediaFilter { all, movie, tv }

/// Genre chips → parser aliases (single-select).
const kSearchFilterGenres = <(String label, String token)>[
  ('Action', 'action'),
  ('Adventure', 'adventure'),
  ('Animation', 'animation'),
  ('Comedy', 'comedy'),
  ('Crime', 'crime'),
  ('Documentary', 'documentary'),
  ('Drama', 'drama'),
  ('Family', 'family'),
  ('Fantasy', 'fantasy'),
  ('History', 'history'),
  ('Horror', 'horror'),
  ('Music', 'music'),
  ('Mystery', 'mystery'),
  ('Romance', 'romance'),
  ('Sci-Fi', 'sci-fi'),
  ('Thriller', 'thriller'),
  ('War', 'war'),
  ('Western', 'western'),
  ('Kids', 'kids'),
];

/// Country chips → parser aliases / ISO (single-select).
const kSearchFilterCountries = <(String label, String token)>[
  ('USA', 'usa'),
  ('UK', 'uk'),
  ('France', 'france'),
  ('Germany', 'germany'),
  ('Japan', 'japan'),
  ('Korea', 'korea'),
  ('India', 'india'),
  ('Italy', 'italy'),
  ('Spain', 'spain'),
  ('Canada', 'canada'),
  ('Australia', 'australia'),
  ('China', 'china'),
  ('Brazil', 'brazil'),
  ('Mexico', 'mexico'),
  ('Sweden', 'sweden'),
  ('Norway', 'norway'),
  ('Denmark', 'denmark'),
  ('Turkey', 'turkey'),
  ('Hong Kong', 'hong kong'),
  ('Taiwan', 'taiwan'),
  ('Thailand', 'thailand'),
];

/// UI-driven Search filters — composed into the structured query string.
class SearchFilters {
  const SearchFilters({
    this.media = SearchMediaFilter.all,
    this.minScore,
    this.yearStart,
    this.yearEnd,
    this.genreToken,
    this.countryToken,
  });

  final SearchMediaFilter media;
  final double? minScore;
  final int? yearStart;
  final int? yearEnd;
  final String? genreToken;
  final String? countryToken;

  static const empty = SearchFilters();

  bool get isEmpty =>
      media == SearchMediaFilter.all &&
      minScore == null &&
      yearStart == null &&
      yearEnd == null &&
      (genreToken == null || genreToken!.isEmpty) &&
      (countryToken == null || countryToken!.isEmpty);

  /// Host structured-search lens: year range only counts when both ends set.
  bool get isActive =>
      media != SearchMediaFilter.all ||
      minScore != null ||
      (yearStart != null && yearEnd != null) ||
      genreToken != null ||
      countryToken != null;

  SearchFilters copyWith({
    SearchMediaFilter? media,
    double? minScore,
    int? yearStart,
    int? yearEnd,
    String? genreToken,
    String? countryToken,
    bool clearMinScore = false,
    bool clearYearStart = false,
    bool clearYearEnd = false,
    bool clearYears = false,
    bool clearGenre = false,
    bool clearCountry = false,
  }) {
    final clearY = clearYears || clearYearStart;
    final clearYe = clearYears || clearYearEnd;
    return SearchFilters(
      media: media ?? this.media,
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      yearStart: clearY ? null : (yearStart ?? this.yearStart),
      yearEnd: clearYe ? null : (yearEnd ?? this.yearEnd),
      genreToken: clearGenre ? null : (genreToken ?? this.genreToken),
      countryToken: clearCountry ? null : (countryToken ?? this.countryToken),
    );
  }

  /// Tokens appended to the typed query for pack structured search.
  String toQuerySuffix() {
    final parts = <String>[];
    switch (media) {
      case SearchMediaFilter.movie:
        parts.add('films');
      case SearchMediaFilter.tv:
        parts.add('series');
      case SearchMediaFilter.all:
        break;
    }
    if (genreToken != null) parts.add(genreToken!);
    if (countryToken != null) parts.add(countryToken!);
    if (minScore != null) {
      final v = minScore!;
      final label =
          v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
      parts.add('>=$label');
    }
    if (yearStart != null && yearEnd != null) {
      if (yearStart == yearEnd) {
        parts.add('$yearStart');
      } else {
        parts.add('$yearStart-$yearEnd');
      }
    }
    return parts.join(' ');
  }

  /// Alias for [composeSearchQuery] — pack structured query string.
  String composeQuery(String query) => composeSearchQuery(query, this);

  List<(String label, VoidCallback clear)> tokenActions(
    void Function(SearchFilters) apply,
  ) {
    final out = <(String, VoidCallback)>[];
    if (media == SearchMediaFilter.movie) {
      out.add((
        'Films',
        () => apply(copyWith(media: SearchMediaFilter.all)),
      ));
    } else if (media == SearchMediaFilter.tv) {
      out.add((
        'Series',
        () => apply(copyWith(media: SearchMediaFilter.all)),
      ));
    }
    if (genreToken != null) {
      final label = kSearchFilterGenres
          .where((e) => e.$2 == genreToken)
          .map((e) => e.$1)
          .firstOrNull;
      out.add((
        label ?? genreToken!,
        () => apply(copyWith(clearGenre: true)),
      ));
    }
    if (countryToken != null) {
      final label = kSearchFilterCountries
          .where((e) => e.$2 == countryToken)
          .map((e) => e.$1)
          .firstOrNull;
      out.add((
        label ?? countryToken!,
        () => apply(copyWith(clearCountry: true)),
      ));
    }
    if (minScore != null) {
      final v = minScore!;
      final label =
          v == v.roundToDouble() ? '≥${v.toInt()}' : '≥${v.toStringAsFixed(1)}';
      out.add((label, () => apply(copyWith(clearMinScore: true))));
    }
    if (yearStart != null && yearEnd != null) {
      final label =
          yearStart == yearEnd ? '$yearStart' : '$yearStart–$yearEnd';
      out.add((label, () => apply(copyWith(clearYears: true))));
    }
    return out;
  }
}

String composeSearchQuery(String typed, SearchFilters filters) {
  final q = typed.trim();
  final suffix = filters.toQuerySuffix();
  if (suffix.isEmpty) return q;
  if (q.isEmpty) return suffix;
  return '$q $suffix';
}

/// Filter chip strip paint — host injects tap/TV via [chipBuilder].
class CatalogSearchFilters extends StatelessWidget {
  const CatalogSearchFilters({
    super.key,
    required this.filters,
    required this.onChanged,
    this.chipBuilder,
  });

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;
  final Widget Function({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  })? chipBuilder;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      final custom = chipBuilder;
      if (custom != null) {
        return custom(label: label, selected: selected, onTap: onTap);
      }
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: ForjaShellColors.brandGreen.withValues(alpha: 0.25),
          checkmarkColor: ForjaShellColors.brandGreen,
          labelStyle: TextStyle(
            color: selected
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.textSecondary,
            fontSize: 12,
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          side: BorderSide(
            color: Colors.white.withValues(alpha: selected ? 0.28 : 0.10),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          chip(
            label: 'All',
            selected: filters.media == SearchMediaFilter.all,
            onTap: () => onChanged(
              filters.copyWith(media: SearchMediaFilter.all),
            ),
          ),
          chip(
            label: 'Movies',
            selected: filters.media == SearchMediaFilter.movie,
            onTap: () => onChanged(
              filters.copyWith(media: SearchMediaFilter.movie),
            ),
          ),
          chip(
            label: 'TV',
            selected: filters.media == SearchMediaFilter.tv,
            onTap: () => onChanged(
              filters.copyWith(media: SearchMediaFilter.tv),
            ),
          ),
        ],
      ),
    );
  }
}
