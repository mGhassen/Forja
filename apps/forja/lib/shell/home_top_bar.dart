import 'package:flutter/material.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/catalog_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Films / TV Shows / Categories menu overlaid on the Home hero.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTopBar(
      tabId: 'home',
      seriesLabel: 'TV Shows',
      mediaCategory: ShellBus.homeCategory,
      selectedCategoryId: ShellBus.homeSelectedGenreId,
      categories: [
        for (final g in homeGenreCategories) (id: g.id, label: g.label),
      ],
      scrollOffset: ShellBus.homeScrollOffset,
      heroHeight: ShellBus.homeHeroHeight,
      onSearch: () {
        pushShellRoute(
          context,
          AppRouter.slideShellRoute((_) => const SearchScreen(overlay: true)),
        );
      },
    );
  }
}
