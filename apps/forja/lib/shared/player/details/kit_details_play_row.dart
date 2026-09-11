import 'package:flutter/material.dart';
import 'package:forja/shared/shell/hero_pill_buttons.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';

export 'package:forja_foundation/widgets/details/play_row.dart'
    show DetailsHeroActionRowFit, DetailsUpcomingNotice, PlayRow;

/// Soft upcoming chip — host alias for [DetailsUpcomingNotice].
typedef KitDetailsUpcomingNotice = DetailsUpcomingNotice;

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
    return TvKitRow(
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

/// Primary play/resume row for hub details heroes (host Interactive / TV).
///
/// Optional [onOpenSources] adds the white link Play (Torrents / Stremio /
/// Nuvio / Forja), matching movie/TV details.
class KitDetailsPlayRow extends StatelessWidget {
  const KitDetailsPlayRow({
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
    final tv = enabled && tvTabId != null;
    final play = HeroPillPlayButton(
      label: label,
      onTap: enabled ? onPlay : null,
      focusNode: enabled ? focusNode : null,
      autoFocus: enabled && autoFocus,
      onUpEdge: tv ? onUpEdge : null,
      tvTabId: tv ? tvTabId : null,
      tvRowId: tv ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tv ? tvItemIndex : null,
    );
    final row = onOpenSources == null
        ? play
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              play,
              const SizedBox(width: 10),
              HeroPillPlayButton(
                label: label,
                icon: Icons.link_rounded,
                tone: HeroPillPlayTone.streaming,
                onTap: enabled ? onOpenSources : null,
                onUpEdge: tv ? onUpEdge : null,
                tvTabId: tv ? tvTabId : null,
                tvRowId: tv ? MediaDetailsTv.heroRowId : null,
                tvItemIndex: tv ? tvSourcesItemIndex : null,
              ),
            ],
          );
    if (enabled) return row;
    return Opacity(opacity: 0.42, child: row);
  }
}
