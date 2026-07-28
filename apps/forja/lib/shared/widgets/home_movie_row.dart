import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:rust/rust.dart';

class HomeMovieRow extends StatelessWidget {
  const HomeMovieRow({
    super.key,
    required this.title,
    required this.movies,
    required this.onMovieTap,
    this.showRank = false,
    this.embedded = false,
    this.titlePadding,
    this.listPadding,
    this.titleGap,
    this.outdentHorizontal = 0,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final String title;
  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;
  final bool showRank;
  final bool embedded;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? listPadding;
  final double? titleGap;
  /// Cancels parent horizontal padding so row insets match home (24px).
  final double outdentHorizontal;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  static double rowHeight(BuildContext context) =>
      HomeMovieCard.cardHeight(context);

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    final tabId = tvTabId ?? ShellTvFocus.currentNavTabId ?? 'home';
    final rowId = tvRowId ?? title;

    final homePad = shellHomeSectionHorizontalPadding(context);
    final outdent = outdentHorizontal;
    final useHomeInsets = outdent > 0;

    final resolvedListPadding = listPadding ??
        (useHomeInsets
            ? EdgeInsets.only(left: homePad)
            : embedded
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(horizontal: homePad));
    final resolvedTitleGap = titleGap ??
        (embedded && !useHomeInsets ? 12.0 : 0.0);

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useHomeInsets)
          ShellSectionTitle(
            title: title,
            padding: titlePadding ??
                EdgeInsets.fromLTRB(
                  homePad,
                  0,
                  homePad,
                  shellHomeSectionBottomGap(context),
                ),
          )
        else if (embedded)
          ShellSectionTitle(
            title: title,
            padding: titlePadding ??
                EdgeInsets.only(bottom: shellHomeSectionBottomGap(context)),
          )
        else
          ShellSectionTitle(
            title: title,
            padding: titlePadding ?? shellSectionTitlePadding(context),
          ),
        if (resolvedTitleGap > 0) SizedBox(height: resolvedTitleGap),
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: HomeMovieCard.cardHeight(context),
            padding: resolvedListPadding,
            itemCount: movies.length,
            separatorBuilder: (_, _) => SizedBox(
              width: showRank
                  ? shellScaled(context, 6).clamp(3.0, 6.0)
                  : shellMovieCardRowGap(context),
            ),
            itemBuilder: (context, index) {
              return HomeMovieCard(
                movie: movies[index],
                onTap: () => onMovieTap(movies[index]),
                rank: showRank ? index + 1 : null,
                listIndex: index,
                tvTabId: tabId,
                tvRowId: rowId,
              );
            },
          ),
        ),
      ],
    );

    final child = outdent <= 0
        ? row
        : LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth + outdent * 2,
                child: Transform.translate(
                  offset: Offset(-outdent, 0),
                  child: row,
                ),
              );
            },
          );

    return TvCatalogRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: tvRowOrder,
      itemCount: movies.length,
      onFocusUp: tvFocusUp,
      child: child,
    );
  }
}
