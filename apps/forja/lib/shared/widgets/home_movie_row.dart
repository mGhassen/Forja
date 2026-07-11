import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:rust/rust.dart';

class HomeMovieRow extends StatefulWidget {
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
  State<HomeMovieRow> createState() => _HomeMovieRowState();
}

class _HomeMovieRowState extends State<HomeMovieRow> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    final rowId = widget.tvRowId ?? widget.title;
    if (tabId != null) {
      shellTvUnregisterRow(tabId: tabId, rowId: rowId);
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    shellTvRegisterRow(
      tabId: widget.tvTabId ?? ShellTvFocus.currentNavTabId ?? 'home',
      rowId: widget.tvRowId ?? widget.title,
      sortOrder: widget.tvRowOrder,
      itemCount: widget.movies.length,
      onFocusUp: widget.tvFocusUp,
    );

    final homePad = shellHomeSectionHorizontalPadding(context);
    final outdent = widget.outdentHorizontal;
    final useHomeInsets = outdent > 0;

    final listPadding = widget.listPadding ??
        (useHomeInsets
            ? EdgeInsets.only(left: homePad)
            : widget.embedded
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(horizontal: homePad));
    final titleGap = widget.titleGap ??
        (widget.embedded && !useHomeInsets ? 12.0 : 0.0);

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useHomeInsets)
          ShellSectionTitle(
            title: widget.title,
            padding: widget.titlePadding ??
                EdgeInsets.fromLTRB(
                  homePad,
                  0,
                  homePad,
                  shellHomeSectionBottomGap(context),
                ),
          )
        else if (widget.embedded)
          ShellSectionTitle(
            title: widget.title,
            padding: widget.titlePadding ??
                EdgeInsets.only(bottom: shellHomeSectionBottomGap(context)),
          )
        else
          ShellSectionTitle(
            title: widget.title,
            padding: widget.titlePadding ?? shellSectionTitlePadding(context),
          ),
        if (titleGap > 0) SizedBox(height: titleGap),
        SizedBox(
          height: HomeMovieCard.cardHeight(context),
          child: FocusTraversalGroup(
            child: NotificationListener<ScrollNotification>(
              onNotification: shellAbsorbHorizontalScroll,
              child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: listPadding,
            itemCount: widget.movies.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: widget.showRank ? shellScaled(context, 6).clamp(3.0, 6.0) : shellMovieCardRowGap(context)),
            itemBuilder: (context, index) {
              return HomeMovieCard(
                movie: widget.movies[index],
                onTap: () => widget.onMovieTap(widget.movies[index]),
                rank: widget.showRank ? index + 1 : null,
                listIndex: index,
                tvTabId: widget.tvTabId ?? ShellTvFocus.currentNavTabId ?? 'home',
                tvRowId: widget.tvRowId ?? widget.title,
              );
            },
          ),
            ),
          ),
        ),
      ],
    );

    if (outdent <= 0) return row;

    return LayoutBuilder(
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
  }
}
