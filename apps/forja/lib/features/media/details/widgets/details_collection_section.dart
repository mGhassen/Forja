// Media details collection list - extracted from details_screen.dart (RFC-019 Phase D).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

class DetailsCollectionSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final Future<void> Function(String id) onOpenItem;

  const DetailsCollectionSection({
    super.key,
    required this.items,
    required this.tvRowOrder,
    required this.onOpenItem,
    this.tvFocusUp,
  });

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    if (policy.useFocusableMoodChips) {
      shellTvRegisterRow(
        tabId: MediaDetailsTv.tabId,
        rowId: 'collection',
        sortOrder: tvRowOrder,
        itemCount: items.length,
        orientation: ShellTvRowOrientation.vertical,
        onFocusUp: tvFocusUp,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Items',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final id = item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? 'Unknown';
            final thumbnail = item['thumbnail']?.toString() ?? '';
            final ratings = item['ratings']?.toString() ?? '';
            final overview = item['overview']?.toString() ?? '';

            return shellFocusableTap(
              context: context,
              onTap: () => onOpenItem(id),
              borderRadius: 12,
              tvTabId: policy.useFocusableMoodChips
                  ? MediaDetailsTv.tabId
                  : null,
              tvRowId: policy.useFocusableMoodChips ? 'collection' : null,
              tvItemIndex: index,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumbnail.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: thumbnail,
                          width: 120,
                          height: 68,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 120,
                            height: 68,
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ratings.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ratings,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (overview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              overview,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white38,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
