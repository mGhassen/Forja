import 'package:flutter/material.dart';
import 'package:forja/features/anime/anime_genre_categories.dart';
import 'package:forja/features/anime/anime_search_screen.dart';
import 'package:forja/features/asian_drama/asian_drama_country_categories.dart';
import 'package:forja/features/asian_drama/asian_drama_search_screen.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/catalog_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Anime hub: Films · Series · Categories + Search.
class AnimeCatalogTopBar extends StatelessWidget {
  const AnimeCatalogTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTopBar(
      tabId: 'anime',
      seriesLabel: 'Series',
      mediaCategory: ShellBus.animeCategory,
      selectedCategoryId: ShellBus.animeSelectedGenreId,
      categories: animeGenreCategories,
      scrollOffset: ShellBus.animeScrollOffset,
      heroHeight: ShellBus.animeHeroHeight,
      onSearch: () {
        pushShellRoute(
          context,
          AppRouter.slideShellRoute((_) => const AnimeSearchScreen()),
        );
      },
    );
  }
}

/// Asian Drama hub: Films · Series · Categories + Search.
class AsianDramaCatalogTopBar extends StatelessWidget {
  const AsianDramaCatalogTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTopBar(
      tabId: 'asian_drama',
      seriesLabel: 'Series',
      mediaCategory: ShellBus.asianDramaCategory,
      selectedCategoryId: ShellBus.asianDramaSelectedCountryId,
      categories: asianDramaCountryCategories,
      scrollOffset: ShellBus.asianDramaScrollOffset,
      heroHeight: ShellBus.asianDramaHeroHeight,
      onSearch: () {
        pushShellRoute(
          context,
          AppRouter.slideShellRoute((_) => const AsianDramaSearchScreen()),
        );
      },
    );
  }
}
