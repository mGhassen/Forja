// Anime continue-watching row - extracted from anime_screen_build.dart.

import 'package:forja/features/anime/widgets/anime_continue_watching_card.dart';
import 'package:forja/features/anime/widgets/anime_widget_imports.dart';

class AnimeContinueWatchingSection extends StatefulWidget {
  final List<Map<String, dynamic>> entries;
  final ScrollController scrollController;
  final int? resumingAnimeId;
  final void Function(Map<String, dynamic> entry) onResume;
  final void Function(Map<String, dynamic> entry) onRemove;
  final void Function(AnimeCard anime) onOpenDetails;
  final int tvRowOrder;
  /// When null, ↑ uses the coordinator previous row (e.g. Trending under hero).
  final VoidCallback? tvFocusUp;

  const AnimeContinueWatchingSection({
    super.key,
    required this.entries,
    required this.scrollController,
    required this.resumingAnimeId,
    required this.onResume,
    required this.onRemove,
    required this.onOpenDetails,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  @override
  State<AnimeContinueWatchingSection> createState() =>
      _AnimeContinueWatchingSectionState();
}

class _AnimeContinueWatchingSectionState
    extends State<AnimeContinueWatchingSection> {
  static const _rowId = 'continue-watching';

  void _scrollBy(BuildContext context, double delta) {
    if (!widget.scrollController.hasClients) return;
    widget.scrollController.animateTo(
      (widget.scrollController.offset + delta).clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _arrowButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
    );
  }

  @override
  void dispose() {
    shellTvUnregisterRow(tabId: 'anime', rowId: _rowId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      shellTvUnregisterRow(tabId: 'anime', rowId: _rowId);
      return const SizedBox.shrink();
    }

    final w = MediaQuery.of(context).size.width;
    final hPad = w < 380 ? 14.0 : 24.0;
    final showArrows = ShellScope.inputPolicyOf(context).scaleOnHover;

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
          trailing: showArrows
              ? [
                  GestureDetector(
                    onTap: () => _scrollBy(context, -400),
                    child: _arrowButton(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _scrollBy(context, 400),
                    child: _arrowButton(Icons.arrow_forward_ios_rounded),
                  ),
                ]
              : const [],
        ),
        SizedBox(
          height: AnimeContinueWatchingCard.cardHeight(context),
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'anime',
                rowId: _rowId,
                sortOrder: widget.tvRowOrder,
                itemCount: widget.entries.length,
                onFocusUp: widget.tvFocusUp,
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
                  controller: widget.scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  // Keep continue cards mounted for D-pad ↑/↓ into this row.
                  scrollCacheExtent: ScrollCacheExtent.pixels(2000),
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  itemCount: widget.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final entry = widget.entries[i];
                    final anime = AnimeCard.fromJson(
                      (entry['anime'] as Map).cast<String, dynamic>(),
                    );
                    final resumeId = entry['animeId'] as int?;
                    return FocusTraversalOrder(
                      order: NumericFocusOrder(i.toDouble()),
                      child: AnimeContinueWatchingCard(
                        listIndex: i,
                        entry: entry,
                        isLoading: resumeId != null &&
                            widget.resumingAnimeId == resumeId,
                        onTap: () => widget.onResume(entry),
                        onRemove: () => widget.onRemove(entry),
                        onInfo: () => widget.onOpenDetails(anime),
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
