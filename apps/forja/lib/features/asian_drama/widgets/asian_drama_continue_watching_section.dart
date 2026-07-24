// Asian Drama continue-watching row — extracted from asian_drama_screen.dart.

import 'package:flutter/rendering.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_continue_watching_card.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_widget_imports.dart';

class AsianDramaContinueWatchingSection extends StatefulWidget {
  final List<Map<String, dynamic>> entries;
  final int? resumingDramaId;
  final void Function(Map<String, dynamic> entry) onResume;
  final void Function(Map<String, dynamic> entry) onRemove;
  final void Function(KdramaCard drama) onOpenDetails;
  final KdramaCard Function(Map<String, dynamic> entry) cardFromEntry;
  final int tvRowOrder;
  /// When null, ↑ uses the coordinator previous row (e.g. Latest under hero).
  final VoidCallback? tvFocusUp;

  const AsianDramaContinueWatchingSection({
    super.key,
    required this.entries,
    required this.resumingDramaId,
    required this.onResume,
    required this.onRemove,
    required this.onOpenDetails,
    required this.cardFromEntry,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  @override
  State<AsianDramaContinueWatchingSection> createState() =>
      _AsianDramaContinueWatchingSectionState();
}

class _AsianDramaContinueWatchingSectionState
    extends State<AsianDramaContinueWatchingSection> {
  static const _rowId = 'continue-watching';

  @override
  void dispose() {
    shellTvUnregisterRow(tabId: 'asian_drama', rowId: _rowId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      shellTvUnregisterRow(tabId: 'asian_drama', rowId: _rowId);
      return const SizedBox.shrink();
    }

    final w = MediaQuery.of(context).size.width;
    final hPad = w < 380 ? 14.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShellSectionTitle(
          title: 'Continue Watching',
          padding: EdgeInsets.fromLTRB(
            24,
            homeUsesShellLayout(context)
                ? ShellTokens.homeSectionTitleTopCompactDesktop
                : ShellTokens.homeSectionTitleTopCompactMobile,
            24,
            16,
          ),
        ),
        SizedBox(
          height: AsianDramaContinueWatchingCard.cardHeight(context),
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'asian_drama',
                rowId: _rowId,
                sortOrder: widget.tvRowOrder,
                itemCount: widget.entries.length,
                onFocusUp: widget.tvFocusUp,
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  scrollCacheExtent: ScrollCacheExtent.pixels(2000),
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  itemCount: widget.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final entry = widget.entries[i];
                    final card = widget.cardFromEntry(entry);
                    final dramaId = (entry['id'] as num?)?.toInt();
                    return FocusTraversalOrder(
                      order: NumericFocusOrder(i.toDouble()),
                      child: AsianDramaContinueWatchingCard(
                        listIndex: i,
                        entry: entry,
                        isLoading: dramaId != null &&
                            widget.resumingDramaId == dramaId,
                        onTap: () => widget.onResume(entry),
                        onRemove: () => widget.onRemove(entry),
                        onInfo: () => widget.onOpenDetails(card),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
