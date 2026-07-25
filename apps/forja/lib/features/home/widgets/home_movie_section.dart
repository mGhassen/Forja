// Home tab section widgets - extracted from home_screen.dart (RFC-019 Phase B).

import 'package:forja/features/home/widgets/home_widget_imports.dart';
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
  void dispose() {
    shellTvUnregisterRow(tabId: 'home', rowId: _rowId);
    super.dispose();
  }

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

        shellTvRegisterRow(
          tabId: 'home',
          rowId: _rowId,
          sortOrder: widget.tvRowOrder,
          itemCount: movies.length,
          onFocusUp: widget.tvFocusUp,
        );

        final sectionTop = shellHomeSectionTitleTop(context, compact: widget.compactTop,
        );

        return Column(
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

  const HomeStaticMovieSection({
    required this.title,
    required this.movies,
    required this.onMovieTap,
    this.tvRowId,
    this.tvRowOrder = 10,
  });

  @override
  State<HomeStaticMovieSection> createState() => HomeStaticMovieSectionState();
}

class HomeStaticMovieSectionState extends State<HomeStaticMovieSection> {
  String get _rowId => widget.tvRowId ?? widget.title;

  @override
  void dispose() {
    shellTvUnregisterRow(tabId: 'home', rowId: _rowId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    shellTvRegisterRow(
      tabId: 'home',
      rowId: _rowId,
      sortOrder: widget.tvRowOrder,
      itemCount: widget.movies.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShellSectionTitle(title: widget.title),
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: HomeMovieCard.cardHeight(context),
            padding: EdgeInsets.symmetric(
              horizontal: shellHomeSectionHorizontalPadding(context),
            ),
            itemCount: widget.movies.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: shellMovieCardRowGap(context)),
            itemBuilder: (context, index) => HomeMovieCard(
              movie: widget.movies[index],
              onTap: () => widget.onMovieTap(widget.movies[index]),
              listIndex: index,
              tvTabId: 'home',
              tvRowId: _rowId,
            ),
          ),
        ),
      ],
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
