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
    bool clearGenre = false,
    bool clearCountry = false,
  }) {
    return SearchFilters(
      media: media ?? this.media,
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      yearStart: clearYearStart ? null : (yearStart ?? this.yearStart),
      yearEnd: clearYearEnd ? null : (yearEnd ?? this.yearEnd),
      genreToken: clearGenre ? null : (genreToken ?? this.genreToken),
      countryToken: clearCountry ? null : (countryToken ?? this.countryToken),
    );
  }

  /// Append filter tokens to a free-text [query] for structured search packs.
  String composeQuery(String query) {
    final parts = <String>[query.trim()];
    switch (media) {
      case SearchMediaFilter.movie:
        parts.add('movie');
      case SearchMediaFilter.tv:
        parts.add('tv');
      case SearchMediaFilter.all:
        break;
    }
    if (minScore != null) parts.add('score:${minScore!.toStringAsFixed(1)}');
    if (yearStart != null && yearEnd != null) {
      parts.add('$yearStart-$yearEnd');
    } else if (yearStart != null) {
      parts.add('$yearStart');
    } else if (yearEnd != null) {
      parts.add('$yearEnd');
    }
    final g = genreToken?.trim();
    if (g != null && g.isNotEmpty) parts.add(g);
    final c = countryToken?.trim();
    if (c != null && c.isNotEmpty) parts.add(c);
    return parts.where((p) => p.isNotEmpty).join(' ');
  }
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
