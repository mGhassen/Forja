import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/movie_poster_card.dart';
import 'package:rust/rust.dart';

String _movieMediaKey(Movie movie) => '${movie.mediaType}:${movie.id}';

List<Movie> mergeMovieRailPages(List<List<Movie>> pages) {
  final seen = <String>{};
  final out = <Movie>[];
  for (final page in pages) {
    for (final movie in page) {
      if (seen.add(_movieMediaKey(movie))) out.add(movie);
    }
  }
  return out;
}

class MoviePosterRow extends StatefulWidget {
  const MoviePosterRow({
    super.key,
    required this.title,
    required this.future,
    required this.onMovieTap,
    this.compactTop = false,
    this.showRank = false,
    this.tvFocusUp,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvTabId,
    this.loadMore,
  });

  final String title;
  final Future<List<Movie>> future;
  final void Function(Movie) onMovieTap;
  final bool compactTop;
  final bool showRank;
  final VoidCallback? tvFocusUp;
  final String? tvRowId;
  final int tvRowOrder;
  final String? tvTabId;
  final Future<List<Movie>> Function()? loadMore;

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
  }) {
    return shellCatalogSectionHeight(
      context,
      compactTop: compactTop,
      cardHeight: MoviePosterCard.cardHeight(context),
    );
  }

  @override
  State<MoviePosterRow> createState() => _MoviePosterRowState();
}

class _MoviePosterRowState extends State<MoviePosterRow> {
  List<Movie>? _last;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.hasData) _last = snapshot.data;
        final movies = snapshot.data ?? _last ?? const <Movie>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        if (movies.isNotEmpty) {
          return MoviePosterRowStatic(
            title: widget.title,
            movies: movies,
            onMovieTap: widget.onMovieTap,
            compactTop: widget.compactTop,
            showRank: widget.showRank,
            tvFocusUp: widget.tvFocusUp,
            tvRowId: widget.tvRowId,
            tvRowOrder: widget.tvRowOrder,
            tvTabId: widget.tvTabId,
            loadMore: widget.loadMore,
          );
        }

        if (loading || !snapshot.hasData) {
          return homeLoadingShimmer(
            homeMovieRowSkeleton(
              context,
              compactTop: widget.compactTop,
              titleWidth: widget.title.length > 12
                  ? 180
                  : widget.title.length * 11.0,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class MoviePosterRowStatic extends StatefulWidget {
  const MoviePosterRowStatic({
    super.key,
    required this.title,
    required this.movies,
    required this.onMovieTap,
    this.tvRowId,
    this.tvRowOrder = 10,
    this.compactTop = false,
    this.showRank = false,
    this.tvFocusUp,
    this.tvTabId,
    this.loadMore,
  });

  final String title;
  final List<Movie> movies;
  final void Function(Movie) onMovieTap;
  final String? tvRowId;
  final int tvRowOrder;
  final bool compactTop;
  final bool showRank;
  final VoidCallback? tvFocusUp;
  final String? tvTabId;
  final Future<List<Movie>> Function()? loadMore;

  @override
  State<MoviePosterRowStatic> createState() => _MoviePosterRowStaticState();
}

class _MoviePosterRowStaticState extends State<MoviePosterRowStatic> {
  List<Movie> _extra = const [];
  bool _loadMoreStarted = false;
  int _loadGen = 0;

  String get _rowId => widget.tvRowId ?? widget.title;

  List<Movie> get _all {
    if (_extra.isEmpty) return widget.movies;
    return mergeMovieRailPages([widget.movies, _extra]);
  }

  @override
  void didUpdateWidget(covariant MoviePosterRowStatic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.movies, widget.movies) &&
        oldWidget.movies != widget.movies) {
      final oldKeys = oldWidget.movies.map(_movieMediaKey).join(',');
      final newKeys = widget.movies.map(_movieMediaKey).join(',');
      if (oldKeys != newKeys) {
        _loadGen++;
        _extra = const [];
        _loadMoreStarted = false;
      }
    }
    if (oldWidget.loadMore != widget.loadMore) {
      _loadGen++;
      _extra = const [];
      _loadMoreStarted = false;
    }
  }

  void _onApproachingEnd() {
    final loadMore = widget.loadMore;
    if (loadMore == null || _loadMoreStarted) return;
    _loadMoreStarted = true;
    final gen = _loadGen;
    loadMore().then((page) {
      if (!mounted || gen != _loadGen || page.isEmpty) return;
      setState(() => _extra = page);
    });
  }

  @override
  Widget build(BuildContext context) {
    final movies = _all;
    if (movies.isEmpty) return const SizedBox.shrink();
    final sectionTop = shellHomeSectionTitleTop(
      context,
      compact: widget.compactTop,
    );
    return TvCatalogRow(
      rowId: _rowId,
      sortOrder: widget.tvRowOrder,
      itemCount: movies.length,
      onFocusUp: widget.tvFocusUp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ShellSectionTitle(
            title: widget.title,
            padding: shellHomeSectionTitlePadding(
              context,
              top: sectionTop,
            ),
          ),
          FocusTraversalGroup(
            child: HorizontalScroller(
              height: MoviePosterCard.cardHeight(context),
              padding: EdgeInsets.symmetric(
                horizontal: shellHomeSectionHorizontalPadding(context),
              ),
              itemCount: movies.length,
              onApproachingEnd:
                  widget.loadMore == null ? null : _onApproachingEnd,
              separatorBuilder: (_, _) => SizedBox(
                width: widget.showRank
                    ? shellScaled(context, 6).clamp(3.0, 6.0)
                    : shellMovieCardRowGap(context),
              ),
              itemBuilder: (context, index) => MoviePosterCard(
                movie: movies[index],
                onTap: () => widget.onMovieTap(movies[index]),
                rank: widget.showRank ? index + 1 : null,
                listIndex: index,
                tvTabId: widget.tvTabId,
                tvRowId: _rowId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget stremioRatingBadgeText(String rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 11),
        const SizedBox(width: 2),
        Text(
          rating,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
