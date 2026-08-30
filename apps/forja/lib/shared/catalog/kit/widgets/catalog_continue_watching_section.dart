import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja/shared/catalog/kit/widgets/catalog_continue_watching_card.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';

/// Generic Continue Watching row — layout widget type `continue`.
class CatalogContinueWatchingSection extends StatelessWidget {
  const CatalogContinueWatchingSection({
    super.key,
    required this.tabId,
    required this.entries,
    required this.scrollController,
    required this.resumingMetaId,
    required this.onResume,
    required this.onRemove,
    required this.onOpenDetails,
    this.tvRowOrder = 1,
    this.tvFocusUp,
  });

  final String tabId;
  final List<Map<String, dynamic>> entries;
  final ScrollController scrollController;
  final String? resumingMetaId;
  final void Function(Map<String, dynamic> entry) onResume;
  final void Function(Map<String, dynamic> entry) onRemove;
  final void Function(Map<String, dynamic> entry) onOpenDetails;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  static const _rowId = 'continue-watching';

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final w = MediaQuery.of(context).size.width;
    final hPad = w < 380 ? 14.0 : 24.0;
    final showArrows = ShellScope.inputPolicyOf(context).scaleOnHover;

    return TvCatalogRow(
      tabId: tabId,
      rowId: _rowId,
      sortOrder: tvRowOrder,
      itemCount: entries.length,
      onFocusUp: tvFocusUp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShellSectionTitle(
            title: 'Continue Watching',
            padding: EdgeInsets.fromLTRB(
              24,
              shellSectionTitleTopCompact(context),
              24,
              16,
            ),
            trailing: showArrows
                ? [
                    _arrow(Icons.arrow_back_ios_new_rounded, -400),
                    const SizedBox(width: 6),
                    _arrow(Icons.arrow_forward_ios_rounded, 400),
                  ]
                : const [],
          ),
          SizedBox(
            height: CatalogContinueWatchingCard.cardHeight(context),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: ListView.separated(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                scrollCacheExtent: ScrollCacheExtent.pixels(2000),
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final metaId = entry['metaId']?.toString();
                  return FocusTraversalOrder(
                    order: NumericFocusOrder(i.toDouble()),
                    child: CatalogContinueWatchingCard(
                      tabId: tabId,
                      listIndex: i,
                      entry: entry,
                      isLoading:
                          metaId != null && resumingMetaId == metaId,
                      onTap: () => onResume(entry),
                      onRemove: () => onRemove(entry),
                      onInfo: () => onOpenDetails(entry),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, double delta) {
    return GestureDetector(
      onTap: () {
        if (!scrollController.hasClients) return;
        scrollController.animateTo(
          (scrollController.offset + delta)
              .clamp(0.0, scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
      ),
    );
  }
}
