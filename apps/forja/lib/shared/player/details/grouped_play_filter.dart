import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/nav/play_filters.dart';
import 'package:forja/shared/player/details/hero_pill_buttons.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';

/// Kit grouped play filter — pack `filters.play[]` with `style: grouped`.
class KitGroupedPlayFilter extends StatelessWidget {
  const KitGroupedPlayFilter({
    super.key,
    required this.spec,
    required this.selected,
    required this.onSelected,
    this.tvTabId,
    this.tvItemIndexStart,
    this.onUpEdge,
  });

  final PlayFilterSpec spec;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? tvTabId;
  final int? tvItemIndexStart;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    if (spec.style != 'grouped' || spec.options.length < 2) {
      return const SizedBox.shrink();
    }
    return HeroPillSegmentedChoice<String>(
      selected: selected,
      onSelected: onSelected,
      tvTabId: tvTabId,
      tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
      tvItemIndexStart: tvItemIndexStart,
      onUpEdge: onUpEdge,
      segments: [
        for (final o in spec.options)
          HeroPillSegment(
            value: o.value,
            label: o.label,
            icon: catalogPlayFilterIcon(o.icon),
          ),
      ],
    );
  }
}
