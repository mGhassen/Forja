import 'package:flutter/material.dart';
import 'package:forja/features/anime/anime_genre_categories.dart';
import 'package:forja/features/asian_drama/asian_drama_country_categories.dart';
import 'package:forja/shared/catalog/shell/catalog_search_screen.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/catalog_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

void openHubCatalogSearch(
  BuildContext context, {
  required String pluginId,
  required String tabId,
  required String hintText,
}) {
  pushShellRoute(
    context,
    AppRouter.slideShellRoute(
      (_) => CatalogSearchScreen(
        pluginId: pluginId,
        tabId: tabId,
        hintText: hintText,
      ),
    ),
  );
}

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
      onSearch: () => openHubCatalogSearch(
        context,
        pluginId: 'anilist',
        tabId: 'anime',
        hintText: 'Search anime…',
      ),
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
      onSearch: () => openHubCatalogSearch(
        context,
        pluginId: 'kisskh-hub',
        tabId: 'asian_drama',
        hintText: 'Search Asian dramas…',
      ),
    );
  }
}

/// Arabic hub: Films · Series + Search (categories empty until pack supplies).
class ArabicCatalogTopBar extends StatelessWidget {
  const ArabicCatalogTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTopBar(
      tabId: 'arabic',
      seriesLabel: 'Series',
      mediaCategory: ShellBus.arabicCategory,
      selectedCategoryId: ShellBus.arabicSelectedCategoryId,
      categories: const [],
      scrollOffset: ShellBus.arabicScrollOffset,
      heroHeight: ShellBus.arabicHeroHeight,
      onSearch: () => openHubCatalogSearch(
        context,
        pluginId: 'arabic-hub',
        tabId: 'arabic',
        hintText: 'بحث… · Search',
      ),
    );
  }
}
