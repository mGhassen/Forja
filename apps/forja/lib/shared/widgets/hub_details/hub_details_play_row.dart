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

/// Primary play/resume row for hub details heroes.
class HubDetailsPlayRow extends StatelessWidget {
  const HubDetailsPlayRow({
    super.key,
    required this.label,
    this.onPlay,
    this.enabled = true,
    this.focusNode,
    this.autoFocus = false,
    this.tvTabId,
    this.tvItemIndex,
    this.onUpEdge,
  });

  final String label;
  final VoidCallback? onPlay;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autoFocus;
  final String? tvTabId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    return HeroPillPlayButton(
      label: label,
      onTap: enabled ? onPlay : null,
      focusNode: focusNode,
      autoFocus: autoFocus,
      onUpEdge: onUpEdge,
      tvTabId: tvTabId,
      tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvItemIndex,
    );
  }
}
