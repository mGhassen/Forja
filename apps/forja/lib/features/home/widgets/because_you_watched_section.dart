// Home tab section widgets - extracted from home_screen.dart (RFC-019 Phase B).

import 'package:forja/features/home/widgets/home_widget_imports.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

class HomeBecauseYouWatchedSection extends StatefulWidget {
  final String seedTitle;
  final String seedPosterPath;
  final Future<List<Movie>> future;
  final Function(Movie) onMovieTap;
  final VoidCallback? onShuffle;

  const HomeBecauseYouWatchedSection({super.key, 
    required this.seedTitle,
    required this.seedPosterPath,
    required this.future,
    required this.onMovieTap,
    required this.onShuffle,
  });

  @override
  State<HomeBecauseYouWatchedSection> createState() =>
      HomeBecauseYouWatchedSectionState();
}

class HomeBecauseYouWatchedSectionState
    extends State<HomeBecauseYouWatchedSection> {
  // Mood chips=3, mood results=4 → shuffle → cards → Trakt (11+).
  static const _shuffleRowId = 'because-shuffle';
  static const _shuffleRowOrder = 5;
  static const _rowId = 'because-watched';
  static const _rowOrder = 6;

  Widget _buildShuffleControl(BuildContext context) {
    final onShuffle = widget.onShuffle;
    if (onShuffle == null) return const SizedBox.shrink();

    if (tvFocusGraphShouldRegister(context)) {
      // Own focus row so ↓ from mood cards lands here before the poster rail.
      return TvCatalogRow(
        rowId: _shuffleRowId,
        sortOrder: _shuffleRowOrder,
        itemCount: 1,
        child: shellFocusableTap(
          context: context,
          onTap: onShuffle,
          borderRadius: 20,
          listIndex: 0,
          navLeftAlways: true,
          tvTabId: 'home',
          tvRowId: _shuffleRowId,
          tvItemIndex: 0,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(
                Icons.shuffle_rounded,
                size: 24,
                color: ForjaShellColors.iconMuted,
              ),
            ),
          ),
        ),
      );
    }

    return ForjaPlainIcon(
      icon: Icons.shuffle_rounded,
      tooltip: 'Pick a different show',
      onTap: onShuffle,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final posterUrl = widget.seedPosterPath.isNotEmpty
        ? TmdbApi.getImageUrl(widget.seedPosterPath)
        : '';

    return Padding(
      padding: shellSectionTitlePadding(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppTheme.bgCard,
              border: Border.all(
                color: ForjaShellColors.borderSubtle,
                width: 1.2,
              ),
            ),
            child: posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppTheme.bgCard),
                    errorWidget: (_, _, _) => Container(color: AppTheme.bgCard),
                  )
                : const Icon(Icons.movie_outlined,
                    color: Colors.white38, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Because you watched',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.seedTitle.isEmpty ? 'recently' : widget.seedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          _buildShuffleControl(context),
        ],
      ),
    );
  }

  Widget _buildCardSkeletonRow() {
    return homeLoadingShimmer(
      Padding(
        padding: const EdgeInsets.only(top: 0),
        child: SizedBox(
          height: HomeMovieCard.cardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: shellHomeSectionHorizontalPadding(context),
            ),
            itemCount: 5,
            separatorBuilder: (_, _) =>
                SizedBox(width: shellMovieCardRowGap(context)),
            itemBuilder: (_, _) => homeCardSkeleton(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final movies = snap.data ?? const <Movie>[];

        if (!loading && movies.isEmpty) return const SizedBox.shrink();

        final count = movies.length.clamp(0, 25);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (loading)
              _buildCardSkeletonRow()
            else
              TvCatalogRow(
                rowId: _rowId,
                sortOrder: _rowOrder,
                itemCount: count,
                child: FocusTraversalGroup(
                  child: HorizontalScroller(
                    height: HomeMovieCard.cardHeight(context),
                    padding: EdgeInsets.symmetric(
                      horizontal: shellHomeSectionHorizontalPadding(context),
                    ),
                    itemCount: count,
                    separatorBuilder: (_, _) =>
                        SizedBox(width: shellMovieCardRowGap(context)),
                    itemBuilder: (context, i) => HomeMovieCard(
                      movie: movies[i],
                      onTap: () => widget.onMovieTap(movies[i]),
                      listIndex: i,
                      tvTabId: 'home',
                      tvRowId: _rowId,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
