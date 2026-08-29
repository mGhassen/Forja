import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters_rail.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// Toggle a vertical-filter option by TMDB watch-provider chip id.
@Deprecated('Use CatalogVerticalFiltersRegistry.toggleOption')
void toggleHomeWatchProvider(int providerId) {
  final spec = CatalogVerticalFiltersRegistry.specFor('home');
  if (spec == null) return;
  for (final o in spec.options) {
    final filter = o.filter;
    if (filter != null &&
        filter['field'] == 'watch_provider' &&
        filter['value'] == providerId) {
      CatalogVerticalFiltersRegistry.toggleOption('home', o.id);
      return;
    }
  }
}

@Deprecated('Use CatalogVerticalFilterTopBarLogo')
class HomeSelectedWatchProviderLogo extends StatelessWidget {
  const HomeSelectedWatchProviderLogo({
    super.key,
    this.width = ShellTokens.shellProviderTopBarIconWidth,
    this.height = ShellTokens.shellProviderTopBarIconHeight,
    this.tvFocus = false,
    this.focusNode,
    this.listIndex,
    this.onDownEdge,
  });

  final double width;
  final double height;
  final bool tvFocus;
  final FocusNode? focusNode;
  final int? listIndex;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    return CatalogVerticalFilterTopBarLogo(
      tabId: 'home',
      width: width,
      height: height,
      tvFocus: tvFocus,
      focusNode: focusNode,
      listIndex: listIndex,
      onDownEdge: onDownEdge,
    );
  }
}

/// Legacy Home rail — [CatalogVerticalFiltersRail] for tab `home`.
@Deprecated('Use CatalogVerticalFiltersRail')
class HomeWatchProviderRail extends StatelessWidget {
  const HomeWatchProviderRail({super.key});

  @override
  Widget build(BuildContext context) {
    return const CatalogVerticalFiltersRail(tabId: 'home');
  }
}

@Deprecated('Use CatalogVerticalFiltersRail')
class HomeWatchProviderStrip extends StatelessWidget {
  const HomeWatchProviderStrip({super.key});

  @override
  Widget build(BuildContext context) => const HomeWatchProviderRail();
}

/// Standalone host kept for tests.
class ShellTopBar extends StatelessWidget {
  const ShellTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: ShellTokens.shellProviderRailWidth,
      child: HomeWatchProviderRail(),
    );
  }
}
