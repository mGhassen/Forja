import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_section_title.dart';
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
  });

  final String title;
  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;
  final bool showRank;
  final bool embedded;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? listPadding;
  final double? titleGap;

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

    final listPadding = widget.listPadding ??
        (widget.embedded
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24));
    final titleGap = widget.titleGap ?? (widget.embedded ? 12.0 : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.embedded)
          Text(widget.title, style: ShellSectionTitle.titleStyle)
        else
          ShellSectionTitle(
            title: widget.title,
            padding: widget.titlePadding ??
                const EdgeInsets.fromLTRB(24, 36, 24, 16),
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
            itemBuilder: (context, index) => HomeMovieCard(
              movie: widget.movies[index],
              onTap: () => widget.onMovieTap(widget.movies[index]),
              rank: widget.showRank ? index + 1 : null,
            ),
          ),
        ),
      ],
    );
  }
}
