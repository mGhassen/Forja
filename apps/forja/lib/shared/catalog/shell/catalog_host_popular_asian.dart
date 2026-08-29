import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/providers/asian_drama_providers.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:rust/rust.dart';

/// Host-owned ranked **Popular** row — TMDB Asian TV today (not KissKH).
class CatalogHostPopularAsian extends ConsumerWidget {
  const CatalogHostPopularAsian({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(asianDramaPopularTodayProvider);
    return async.when(
      loading: () => homeLoadingShimmer(
        homeMovieRowSkeleton(context, titleWidth: 120),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (movies) {
        if (movies.isEmpty) return const SizedBox.shrink();
        return HubCatalogSection<Movie>(
          title: 'Popular',
          items: movies,
          showRank: true,
          cardAspect: HubPosterAspect.landscape,
          tvTabId: 'asian_drama',
          tvRowId: 'popular',
          cardBuilder: (context, movie, index) {
            final path = movie.backdropPath.isNotEmpty
                ? movie.backdropPath
                : movie.posterPath;
            return HubPosterCard(
              imageUrl: path.isEmpty ? '' : TmdbApi.getImageUrl(path),
              title: movie.title,
              subtitle: movie.releaseDate.length >= 4
                  ? movie.releaseDate.substring(0, 4)
                  : null,
              rating: movie.voteAverage > 0 ? movie.voteAverage : null,
              rank: index + 1,
              listIndex: index,
              tvTabId: 'asian_drama',
              tvRowId: 'popular',
              aspect: HubPosterAspect.landscape,
              onTap: () => AppRouter.openDetails(context, movie: movie),
            );
          },
        );
      },
    );
  }
}
