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
  String get _rowId => widget.tvRowId ?? widget.title;

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
                  separatorBuilder: (_, _) => SizedBox(
                    width: widget.showRank
                        ? shellScaled(context, 6).clamp(3.0, 6.0)
                        : shellMovieCardRowGap(context),
                  ),
                  itemBuilder: (context, index) {
                    return HomeMovieCard(
                      movie: movies[index],
                      onTap: () => widget.onMovieTap(movies[index]),
                      rank: widget.showRank ? index + 1 : null,
                      listIndex: index,
                      tvTabId: 'home',
                      tvRowId: _rowId,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeStaticMovieSection extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final Function(Movie) onMovieTap;
  final String? tvRowId;
  final int tvRowOrder;
  final bool compactTop;
  final bool showRank;
  final VoidCallback? tvFocusUp;

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
  });

  String get _rowId => tvRowId ?? title;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final sectionTop = shellHomeSectionTitleTop(
      context,
      compact: compactTop,
    );
    return TvCatalogRow(
      rowId: _rowId,
      sortOrder: tvRowOrder,
      itemCount: movies.length,
      onFocusUp: tvFocusUp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ShellSectionTitle(
            title: title,
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
              separatorBuilder: (_, _) => SizedBox(
                width: showRank
                    ? shellScaled(context, 6).clamp(3.0, 6.0)
                    : shellMovieCardRowGap(context),
              ),
              itemBuilder: (context, index) => HomeMovieCard(
                movie: movies[index],
                onTap: () => onMovieTap(movies[index]),
                rank: showRank ? index + 1 : null,
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
