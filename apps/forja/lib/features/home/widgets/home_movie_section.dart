// Home tab section widgets - extracted from home_screen.dart (RFC-019 Phase B).

import 'package:forja/features/home/widgets/home_widget_imports.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

class HomeMovieSection extends StatefulWidget {
  final String title;
  final Future<List<Movie>> future;
  final Function(Movie) onMovieTap;
  final bool compactTop;
  final bool showRank;
  final VoidCallback? tvFocusUp;
  final String? tvRowId;
  final int tvRowOrder;
  final Future<List<Movie>> Function()? loadMore;

  const HomeMovieSection({
    super.key,
    required this.title,
    required this.future,
    required this.onMovieTap,
    this.compactTop = false,
    this.showRank = false,
    this.tvFocusUp,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.loadMore,
  });

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
  }) {
    return shellCatalogSectionHeight(
      context,
      compactTop: compactTop,
      cardHeight: HomeMovieCard.cardHeight(context),
    );
  }

  @override
  State<HomeMovieSection> createState() => HomeMovieSectionState();
}

class HomeMovieSectionState extends State<HomeMovieSection> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final movies = snapshot.data ?? const <Movie>[];

        if (loading || movies.isEmpty) {
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
        }

        return HomeStaticMovieSection(
          title: widget.title,
          movies: movies,
          onMovieTap: widget.onMovieTap,
          compactTop: widget.compactTop,
          showRank: widget.showRank,
          tvFocusUp: widget.tvFocusUp,
          tvRowId: widget.tvRowId,
          tvRowOrder: widget.tvRowOrder,
          loadMore: widget.loadMore,
        );
      },
    );
  }
}

class HomeStaticMovieSection extends StatefulWidget {
  final String title;
  final List<Movie> movies;
  final Function(Movie) onMovieTap;
  final String? tvRowId;
  final int tvRowOrder;
  final bool compactTop;
  final bool showRank;
  final VoidCallback? tvFocusUp;
  /// Fetches the next TMDB page when the scroller nears the end (once).
  final Future<List<Movie>> Function()? loadMore;

  const HomeStaticMovieSection({
    super.key,
    required this.title,
    required this.movies,
    required this.onMovieTap,
    this.tvRowId,
    this.tvRowOrder = 10,
    this.compactTop = false,
    this.showRank = false,
    this.tvFocusUp,
    this.loadMore,
  });

  @override
  State<HomeStaticMovieSection> createState() => _HomeStaticMovieSectionState();
}

class _HomeStaticMovieSectionState extends State<HomeStaticMovieSection> {
  List<Movie> _extra = const [];
  bool _loadMoreStarted = false;
  int _loadGen = 0;

  String get _rowId => widget.tvRowId ?? widget.title;

  List<Movie> get _all {
    if (_extra.isEmpty) return widget.movies;
    return mergeHomeRailPages([widget.movies, _extra]);
  }

  @override
  void didUpdateWidget(covariant HomeStaticMovieSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filter / pool swap — drop page-2 append so we don't mix catalogs.
    if (!identical(oldWidget.movies, widget.movies) &&
        oldWidget.movies != widget.movies) {
      final oldKeys = oldWidget.movies.map(homeMediaKey).join(',');
      final newKeys = widget.movies.map(homeMediaKey).join(',');
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
              height: HomeMovieCard.cardHeight(context),
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
              itemBuilder: (context, index) => HomeMovieCard(
                movie: movies[index],
                onTap: () => widget.onMovieTap(movies[index]),
                rank: widget.showRank ? index + 1 : null,
                listIndex: index,
                tvTabId: 'home',
                tvRowId: _rowId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating badge for string ratings (Stremio).
Widget homeRatingBadgeText(String rating) {
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
        Text(rating, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
