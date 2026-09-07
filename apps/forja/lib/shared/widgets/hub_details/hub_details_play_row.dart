import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
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

/// Soft “not playable yet” chip for hub details heroes (upcoming titles).
///
/// Height matches [ShellTokens.shellButtonHeight] so hero footer budget fits.
class HubDetailsUpcomingNotice extends StatelessWidget {
  const HubDetailsUpcomingNotice({
    super.key,
    this.releaseDateLabel,
  });

  static const double height = ShellTokens.shellButtonHeight;

  /// Human premiere label (e.g. `Jun 14, 2026`), or null/empty if unknown.
  final String? releaseDateLabel;

  @override
  Widget build(BuildContext context) {
    final date = releaseDateLabel?.trim() ?? '';
    final hasDate = date.isNotEmpty;
    final label = hasDate ? 'Coming soon · $date' : 'Coming soon';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Colors.amber.shade200,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.96),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
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
