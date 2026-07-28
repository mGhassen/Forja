// Home tab section widgets - extracted from home_screen.dart (RFC-019 Phase B).

import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/features/home/widgets/home_widget_imports.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/my_list_button.dart';

class HomeStremioCatalogSection extends StatelessWidget {
  final Map<String, dynamic> catalog;
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onItemTap;
  final VoidCallback onShowAll;
  final int tvRowOrder;

  const HomeStremioCatalogSection({
    super.key,
    required this.catalog,
    required this.items,
    required this.onItemTap,
    required this.onShowAll,
    this.tvRowOrder = 15,
  });

  String get _rowId {
    final cat = catalog;
    return 'stremio-${cat['addonBaseUrl']}-${cat['catalogId']}';
  }

  @override
  Widget build(BuildContext context) {
    final cat = catalog;
    final addonName = cat['addonName'] as String;
    final catalogName = cat['catalogName'] as String;
    final itemCount = items.length.clamp(0, 20);
    // Cards occupy 0..itemCount-1; Show All is itemCount (in the title row).
    final graphCount = itemCount + 1;

    return TvCatalogRow(
      rowId: _rowId,
      sortOrder: tvRowOrder,
      itemCount: graphCount,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: shellHomeSectionTitlePadding(
              context,
              bottom: shellScaled(context, 14).clamp(4.0, 14.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$addonName · $catalogName',
                        style: ShellSectionTitle.titleStyle,
                      ),
                    ],
                  ),
                ),
                shellFocusableTap(
                  context: context,
                  onTap: onShowAll,
                  borderRadius: 20,
                  listIndex: itemCount,
                  navLeftAlways: true,
                  tvTabId: 'home',
                  tvRowId: _rowId,
                  tvItemIndex: itemCount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Show All',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          FocusTraversalGroup(
            child: HorizontalScroller(
              height: HomeMovieCard.cardHeight(context),
              padding: EdgeInsets.symmetric(
                horizontal: shellHomeSectionHorizontalPadding(context),
              ),
              itemCount: itemCount,
              separatorBuilder: (_, _) =>
                  SizedBox(width: shellMovieCardRowGap(context)),
              itemBuilder: (context, index) {
                final item = items[index];
                return HomeStremioCatalogCard(
                  item: item,
                  listIndex: index,
                  tvRowId: _rowId,
                  onTap: () => onItemTap(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeStremioCatalogCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? listIndex;
  final String? tvRowId;
  final VoidCallback onTap;

  const HomeStremioCatalogCard({
    super.key,
    required this.item,
    required this.onTap,
    this.listIndex,
    this.tvRowId,
  });

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unknown';
    final rating = item['imdbRating']?.toString() ?? '';
    final cardWidth = HomeMovieCard.cardWidth(context);
    final cardHeight = HomeMovieCard.cardHeight(context);

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 14,
      scaleOnFocus: 1.05,
      showFocusBorder: true,
      listIndex: listIndex,
      tvTabId: 'home',
      tvRowId: tvRowId,
      tvItemIndex: listIndex,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppTheme.bgDark,
                child: poster.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        placeholder: (_, _) =>
                            ColoredBox(color: AppTheme.bgDark),
                        errorWidget: (_, _, _) => Container(
                          color: AppTheme.bgDark,
                          child: Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
              if (rating.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: homeRatingBadgeText(rating),
                ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: MyListButton.stremio(
                  stremioItem: item,
                  excludeFromTvTraversal: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
