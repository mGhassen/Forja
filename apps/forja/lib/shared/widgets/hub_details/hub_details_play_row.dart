import 'package:flutter/material.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Registers [MediaDetailsTv.heroRowId] for hub-style hero action clusters.
class DetailsHeroTvActionScope extends StatefulWidget {
  const DetailsHeroTvActionScope({
    super.key,
    required this.tabId,
    required this.itemCount,
    this.onFocusUp,
    required this.child,
  });

  final String tabId;
  final int itemCount;
  final VoidCallback? onFocusUp;
  final Widget child;

  @override
  State<DetailsHeroTvActionScope> createState() =>
      _DetailsHeroTvActionScopeState();
}

class _DetailsHeroTvActionScopeState extends State<DetailsHeroTvActionScope> {
  @override
  void dispose() {
    shellTvUnregisterRow(tabId: widget.tabId, rowId: MediaDetailsTv.heroRowId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount > 0) {
      shellTvRegisterRow(
        tabId: widget.tabId,
        rowId: MediaDetailsTv.heroRowId,
        sortOrder: MediaDetailsTv.heroRowSortOrder,
        itemCount: widget.itemCount,
        onFocusUp: widget.onFocusUp,
      );
    }
    return widget.child;
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
    this.tvTabId,
    this.tvItemIndex,
  });

  final String label;
  final VoidCallback? onPlay;
  final bool enabled;
  final FocusNode? focusNode;
  final String? tvTabId;
  final int? tvItemIndex;

  @override
  Widget build(BuildContext context) {
    return HeroPillPlayButton(
      label: label,
      onTap: enabled ? onPlay : null,
      focusNode: focusNode,
      tvTabId: tvTabId,
      tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvItemIndex,
    );
  }
}
