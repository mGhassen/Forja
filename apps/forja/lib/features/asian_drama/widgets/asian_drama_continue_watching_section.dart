// Asian Drama continue-watching row — extracted from asian_drama_screen.dart.

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_continue_watching_card.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_widget_imports.dart';

class AsianDramaContinueWatchingSection extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final int? resumingDramaId;
  final void Function(Map<String, dynamic> entry) onResume;
  final void Function(Map<String, dynamic> entry) onRemove;
  final void Function(KdramaCard drama) onOpenDetails;
  final KdramaCard Function(Map<String, dynamic> entry) cardFromEntry;

  const AsianDramaContinueWatchingSection({
    super.key,
    required this.entries,
    required this.resumingDramaId,
    required this.onResume,
    required this.onRemove,
    required this.onOpenDetails,
    required this.cardFromEntry,
  });

  @override
  Widget build(BuildContext context) {
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
                rowId: 'continue-watching',
                sortOrder: 0,
                itemCount: entries.length,
                onFocusUp: () => ShellTvFocusCoordinator.focusHero(
                  tabId: 'asian_drama',
                ),
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    final card = cardFromEntry(entry);
                    final dramaId = (entry['id'] as num?)?.toInt();
                    return AsianDramaContinueWatchingCard(
                      listIndex: i,
                      entry: entry,
                      isLoading: dramaId != null && resumingDramaId == dramaId,
                      onTap: () => onResume(entry),
                      onRemove: () => onRemove(entry),
                      onInfo: () => onOpenDetails(card),
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
