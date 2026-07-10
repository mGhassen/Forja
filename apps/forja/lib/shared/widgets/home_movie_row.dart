import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
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

  static double rowHeight(BuildContext context) =>
      HomeMovieCard.cardHeight(context);

  @override
  State<HomeMovieRow> createState() => _HomeMovieRowState();
}

class _HomeMovieRowState extends State<HomeMovieRow> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final homePad = ShellTokens.homeSectionHorizontalPadding;
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
                EdgeInsets.fromLTRB(homePad, 0, homePad, 16),
          )
        else if (widget.embedded)
          ShellSectionTitle(
            title: widget.title,
            padding: widget.titlePadding ??
                const EdgeInsets.only(bottom: 16),
          )
        else
          ShellSectionTitle(
            title: widget.title,
            padding: widget.titlePadding ??
                EdgeInsets.fromLTRB(homePad, 36, homePad, 16),
          ),
        if (titleGap > 0) SizedBox(height: titleGap),
        SizedBox(
          height: HomeMovieCard.cardHeight(context),
          child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: listPadding,
            itemCount: widget.movies.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: widget.showRank ? 6 : 14),
            itemBuilder: (context, index) {
              return HomeMovieCard(
                movie: widget.movies[index],
                onTap: () => widget.onMovieTap(widget.movies[index]),
                rank: widget.showRank ? index + 1 : null,
                listIndex: index,
              );
            },
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
