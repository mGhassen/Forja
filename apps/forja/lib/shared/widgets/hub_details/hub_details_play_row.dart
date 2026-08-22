import 'package:flutter/material.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';

/// Scales hero action rows down on narrow viewports instead of overflowing.
class DetailsHeroActionRowFit extends StatelessWidget {
  const DetailsHeroActionRowFit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

/// Registers [MediaDetailsTv.heroRowId] for hub-style hero action clusters.
class DetailsHeroTvActionScope extends StatelessWidget {
  const DetailsHeroTvActionScope({
    super.key,
    required this.tabId,
    required this.itemCount,
    this.onFocusUp,
    this.onFocusDown,
    required this.child,
  });

  final String tabId;
  final int itemCount;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TvCatalogRow(
      tabId: tabId,
      rowId: MediaDetailsTv.heroRowId,
      sortOrder: MediaDetailsTv.heroRowSortOrder,
      itemCount: itemCount,
      onFocusUp: onFocusUp,
      onFocusDown: onFocusDown,
      child: child,
    );
  }
}

/// Soft “not playable yet” notice for hub details heroes (upcoming titles).
class HubDetailsUpcomingNotice extends StatelessWidget {
  const HubDetailsUpcomingNotice({
    super.key,
    this.releaseDateLabel,
  });

  /// Human premiere label (e.g. `Jun 14, 2026`), or null/empty if unknown.
  final String? releaseDateLabel;

  @override
  Widget build(BuildContext context) {
    final date = releaseDateLabel?.trim() ?? '';
    final hasDate = date.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_rounded,
                color: Colors.amber.shade200,
                size: 22,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Coming soon',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasDate
                          ? 'Streams unlock around $date'
                          : 'Not published yet — check back when it premieres',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Poppins',
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary play/resume row for hub details heroes.
///
/// Optional [onOpenSources] adds the white link Play (Torrents / Stremio /
/// Nuvio / Forja), matching movie/TV details.
class HubDetailsPlayRow extends StatelessWidget {
  const HubDetailsPlayRow({
    super.key,
    required this.label,
    this.onPlay,
    this.onOpenSources,
    this.enabled = true,
    this.focusNode,
    this.autoFocus = false,
    this.tvTabId,
    this.tvItemIndex,
    this.tvSourcesItemIndex,
    this.onUpEdge,
  });

  final String label;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenSources;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autoFocus;
  final String? tvTabId;
  final int? tvItemIndex;
  final int? tvSourcesItemIndex;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    final play = HeroPillPlayButton(
      label: label,
      onTap: enabled ? onPlay : null,
      focusNode: focusNode,
      autoFocus: autoFocus,
      onUpEdge: onUpEdge,
      tvTabId: tvTabId,
      tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvItemIndex,
    );
    if (onOpenSources == null) return play;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        play,
        const SizedBox(width: 10),
        HeroPillPlayButton(
          label: label,
          icon: Icons.link_rounded,
          tone: HeroPillPlayTone.streaming,
          onTap: enabled ? onOpenSources : null,
          onUpEdge: onUpEdge,
          tvTabId: tvTabId,
          tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
          tvItemIndex: tvSourcesItemIndex,
        ),
      ],
    );
  }
}
