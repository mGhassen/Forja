import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/rows/home_movie_section.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Host-owned Trakt rails — Recommended / Upcoming Schedule / Upcoming Movies.
class CatalogHostTrakt extends StatefulWidget {
  const CatalogHostTrakt({super.key});

  @override
  State<CatalogHostTrakt> createState() => _CatalogHostTraktState();
}

class _CatalogHostTraktState extends State<CatalogHostTrakt> {
  final _api = TmdbApi();
  var _loading = true;
  List<Movie> _recs = const [];
  List<Movie> _shows = const [];
  List<Movie> _movies = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Movie>> _resolve(
    List<({int tmdbId, String type})> entries,
  ) async {
    final out = <Movie>[];
    for (var i = 0; i < entries.length; i += 5) {
      final batch = entries.skip(i).take(5);
      final results = await Future.wait(
        batch.map((e) async {
          try {
            return e.type == 'tv'
                ? await _api.getTvDetails(e.tmdbId)
                : await _api.getMovieDetails(e.tmdbId);
          } catch (_) {
            return null;
          }
        }),
      );
      out.addAll(results.whereType<Movie>());
    }
    return out;
  }

  Future<void> _load() async {
    final trakt = TraktService();
    try {
      if (!await trakt.isLoggedIn()) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final movieRecs = await trakt.getRecommendations('movies');
      final showRecs = await trakt.getRecommendations('shows');
      final recEntries = <({int tmdbId, String type})>[];
      for (final rec in [...movieRecs, ...showRecs].take(20)) {
        final item = rec['movie'] ?? rec['show'];
        if (item is! Map) continue;
        final ids = item['ids'];
        if (ids is! Map) continue;
        final tmdbId = ids['tmdb'];
        if (tmdbId is! int) continue;
        recEntries.add((
          tmdbId: tmdbId,
          type: rec.containsKey('show') ? 'tv' : 'movie',
        ));
      }

      final showsRaw = await trakt.getCalendarShows(days: 14);
      final showEntries = <({int tmdbId, String type})>[];
      for (final entry in showsRaw.take(20)) {
        final show = entry['show'];
        if (show is! Map) continue;
        final ids = show['ids'];
        if (ids is! Map) continue;
        final tmdbId = ids['tmdb'];
        if (tmdbId is! int) continue;
        showEntries.add((tmdbId: tmdbId, type: 'tv'));
      }

      final moviesRaw = await trakt.getCalendarMovies(days: 30);
      final movieEntries = <({int tmdbId, String type})>[];
      for (final entry in moviesRaw.take(20)) {
        final movie = entry['movie'];
        if (movie is! Map) continue;
        final ids = movie['ids'];
        if (ids is! Map) continue;
        final tmdbId = ids['tmdb'];
        if (tmdbId is! int) continue;
        movieEntries.add((tmdbId: tmdbId, type: 'movie'));
      }

      final results = await Future.wait([
        _resolve(recEntries),
        _resolve(showEntries),
        _resolve(movieEntries),
      ]);
      if (!mounted) return;
      setState(() {
        _recs = results[0];
        _shows = results[1];
        _movies = results[2];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Movie m) => AppRouter.openDetails(context, movie: m);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return homeLoadingShimmer(
        homeMovieRowSkeleton(context, titleWidth: 180),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_recs.isNotEmpty)
          HomeStaticMovieSection(
            title: 'Recommended for You',
            movies: _recs,
            onMovieTap: _open,
            tvRowId: 'trakt-recs',
            tvRowOrder: 11,
          ),
        if (_shows.isNotEmpty)
          HomeStaticMovieSection(
            title: 'Upcoming Schedule',
            movies: _shows,
            onMovieTap: _open,
            tvRowId: 'trakt-shows',
            tvRowOrder: 12,
          ),
        if (_movies.isNotEmpty)
          HomeStaticMovieSection(
            title: 'Upcoming Movies',
            movies: _movies,
            onMovieTap: _open,
            tvRowId: 'trakt-movies',
            tvRowOrder: 13,
          ),
      ],
    );
  }
}
