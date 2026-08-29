import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/home/home_catalog_rotate.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shared/catalog/kit/rows/home_movie_section.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:rust/rust.dart';

/// Host-owned random (or filter-locked) genre discovery rows — old Home bottom.
class CatalogHostGenreRows extends StatefulWidget {
  const CatalogHostGenreRows({super.key, this.tvRowOrderBase = 20});

  final int tvRowOrderBase;

  @override
  State<CatalogHostGenreRows> createState() => _CatalogHostGenreRowsState();
}

class _CatalogHostGenreRowsState extends State<CatalogHostGenreRows> {
  final _api = TmdbApi();
  int _gen = 0;
  List<
      ({
        String id,
        String label,
        Future<List<Movie>> future,
        List<Movie>? pool,
      })> _rows = const [];

  @override
  void initState() {
    super.initState();
    ShellBus.homeSelectedGenreId.addListener(_onFilter);
    ShellBus.homeCategory.addListener(_onFilter);
    CatalogVerticalFiltersRegistry.selectedIdFor('home').addListener(_onFilter);
    _reset();
  }

  @override
  void dispose() {
    ShellBus.homeSelectedGenreId.removeListener(_onFilter);
    ShellBus.homeCategory.removeListener(_onFilter);
    CatalogVerticalFiltersRegistry.selectedIdFor('home').removeListener(
      _onFilter,
    );
    super.dispose();
  }

  void _onFilter() => _reset();

  Future<List<Movie>> _fetchCategory(
    ({
      String id,
      String label,
      List<int> movieGenres,
      List<int> tvGenres,
    }) category,
  ) async {
    final providerId = CatalogVerticalFiltersRegistry.watchProviderIdFor('home');
    final selected = ShellBus.homeSelectedGenreId.value;
    final looked = lookupHomeGenre(selected);
    final movieGenres = looked?.movieGenres ?? category.movieGenres;
    final tvGenres = looked?.tvGenres ?? category.tvGenres;
    final bucket = homeCatalogHourBucket();

    Future<List<Movie>> movies() => rotateHomeRailPool(
          bucket: bucket,
          salt: 'genre-${category.id}-m',
          fetchPage: (page) => _api.discoverMovies(
            genres: movieGenres,
            watchProviderId: providerId,
            page: page,
          ),
        );
    Future<List<Movie>> shows() => rotateHomeRailPool(
          bucket: bucket,
          salt: 'genre-${category.id}-tv',
          fetchPage: (page) => _api.discoverTvShows(
            genres: tvGenres,
            watchProviderId: providerId,
            page: page,
          ),
        );

    final pair = await Future.wait([movies(), shows()]);
    final filter = ShellBus.homeCategory.value;
    if (filter == ShellHomeCategory.films) return pair[0];
    if (filter == ShellHomeCategory.tvShows) return pair[1];
    // Interleave movie/tv like old `_fetchMixed`.
    final out = <Movie>[];
    final seen = <String>{};
    void add(Movie m) {
      final key = '${m.mediaType}:${m.id}';
      if (seen.add(key)) out.add(m);
    }

    final a = pair[0];
    final b = pair[1];
    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      if (i < a.length) add(a[i]);
      if (i < b.length) add(b[i]);
    }
    return out;
  }

  void _reset() {
    final selectedGenreId = ShellBus.homeSelectedGenreId.value;
    final List<
        ({
          String id,
          String label,
          List<int> movieGenres,
          List<int> tvGenres,
        })> picked;
    if (selectedGenreId != null) {
      picked = homeGenreCategories
          .where((c) => c.id == selectedGenreId)
          .toList();
    } else {
      final pool = List.of(homeGenreCategories)
        ..shuffle(homeCatalogRandom(homeCatalogHourBucket(), 'genre-row-picks'));
      picked = pool.take(3).toList();
    }
    final gen = ++_gen;
    final fetches = [for (final c in picked) _fetchCategory(c)];
    setState(() {
      _rows = [
        for (var i = 0; i < picked.length; i++)
          (
            id: picked[i].id,
            label: picked[i].label,
            future: fetches[i].then((pool) {
              if (!mounted || gen != _gen) return pool;
              setState(() {
                _rows = [
                  for (final row in _rows)
                    if (row.id == picked[i].id)
                      (
                        id: row.id,
                        label: row.label,
                        future: row.future,
                        pool: pool,
                      )
                    else
                      row,
                ];
              });
              return pool;
            }),
            pool: null,
          ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _rows.length; i++)
          HomeMovieSection(
            key: ValueKey('genre-${_rows[i].id}'),
            title: _rows[i].label,
            future: _rows[i].pool != null
                ? Future<List<Movie>>.value(_rows[i].pool!)
                : _rows[i].future,
            onMovieTap: (m) => AppRouter.openDetails(context, movie: m),
            tvRowId: 'genre-${_rows[i].id}',
            tvRowOrder: widget.tvRowOrderBase + i,
          ),
      ],
    );
  }
}
