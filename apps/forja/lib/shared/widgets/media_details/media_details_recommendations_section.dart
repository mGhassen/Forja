import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/home_movie_row.dart';
import 'package:rust/rust.dart';

/// Horizontal "More Like This" row below media details hero.
class MediaDetailsRecommendationsSection extends StatelessWidget {
  const MediaDetailsRecommendationsSection({
    super.key,
    required this.movies,
    required this.onMovieTap,
    this.title = 'More Like This',
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final List<Movie> movies;
  final void Function(Movie movie) onMovieTap;
  final String title;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return HomeMovieRow(
      title: title,
      movies: movies,
      onMovieTap: onMovieTap,
      tvTabId: tvTabId,
      tvRowId: tvRowId ?? 'recommendations',
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
    );
  }
}
