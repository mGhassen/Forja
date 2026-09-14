import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/kit/slots/slots.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/widgets/chrome/layout_stack.dart';

/// Recursive validate+paint: pack node → foundation widget from props maps.
///
/// Slot types (`hero`, `mood`, …) live under [slots/]. Card/rail paint is
/// [PackPaintArtifact] only — no parallel mappers.
class PackPaintTree extends StatelessWidget {
  const PackPaintTree({
    super.key,
    required this.spec,
    required this.pluginId,
    this.packSourceUrl,
    this.tabId,
  });

  final Map<String, dynamic> spec;
  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;

  @override
  Widget build(BuildContext context) {
    if (spec['hideWhenTypeFilter'] == true &&
        catalogChromeHidesTypeFilterRails(tabId)) {
      return const SizedBox.shrink();
    }

    final type = LayoutTypes.normalize(
      (spec['type'] ?? '').toString(),
      spec,
    );

    // Slots own load / store — dispatch before generic load wrap.
    switch (type) {
      case LayoutTypes.hero:
        return PackHeroSlot(
          spec: spec,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      case LayoutTypes.verticalFilters:
        return PackVerticalFiltersSlot(
          spec: spec,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      case LayoutTypes.continueWatching:
        return PackContinueSlot(
          pluginId: pluginId,
          tabId: tabId,
          mergeHomeWatchHistory: spec['mergeHomeWatchHistory'] == true,
        );
      case LayoutTypes.mood:
        return PackMoodSlot(
          spec: spec,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      case LayoutTypes.because:
        return PackBecauseSlot(
          spec: spec,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      case LayoutTypes.list:
        final listLoad = packLoadSpec(spec['load']) ??
            (action: 'feed', params: <String, dynamic>{});
        return PackLoadedPaint(
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
          action: listLoad.action,
          params: listLoad.params,
          fallbackSpec: spec,
          builder: (ctx, merged) => PackListSlot(
            spec: merged,
            pluginId: pluginId,
          ),
        );
      case LayoutTypes.topBar:
      case LayoutTypes.categoryBar:
        // Top bar / category chrome still WIP — do not Column-dump actions.
        return const SizedBox.shrink();
      case LayoutTypes.menu:
        return PackMenuSlot(spec: spec);
      case LayoutTypes.tabs:
        return PackTabsSlot(spec: spec);
    }

    final load = packLoadSpec(spec['load']);
    if (load != null) {
      return PackLoadedPaint(
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
        action: load.action,
        params: load.params,
        fallbackSpec: spec,
        builder: (ctx, merged) {
          final mergedType = LayoutTypes.normalize(
            (merged['type'] ?? '').toString(),
            merged,
          );
          // Always list-slot feed payloads — never recurse into Column-of-items.
          if (mergedType == LayoutTypes.list || merged['items'] is List) {
            return PackListSlot(spec: merged, pluginId: pluginId);
          }
          return PackPaintTree(
            spec: merged,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        },
      );
    }
    return _paintNode(context, spec);
  }

  Widget _paintNode(BuildContext context, Map<String, dynamic> node) {
    final type = LayoutTypes.normalize(
      (node['type'] ?? '').toString(),
      node,
    );

    if (type == LayoutTypes.list) {
      return PackListSlot(spec: node, pluginId: pluginId);
    }

    if (LayoutTypes.isStack(type) || type == LayoutTypes.stack) {
      return LayoutStack(
        spec: node,
        childBuilder: (child, _) => PackPaintTree(
          spec: child,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        ),
      );
    }

    final paint = node['paint'];
    if (paint is Map) {
      return PackPaintArtifact.fromPaint(
        context,
        pluginId: pluginId,
        paint: Map<String, dynamic>.from(paint),
        open: node['open'] ?? paint['open'],
        meta: node['meta'] ?? paint['meta'],
      );
    }

    if (type == LayoutTypes.row || type == 'rail' || type == 'ranked') {
      return PackPaintArtifact.posterRow(
        context,
        node: node,
        pluginId: pluginId,
      );
    }

    // Feed / kit.list payload lives in `items` — never Column (expand overflow).
    if (node['items'] is List) {
      return PackListSlot(spec: node, pluginId: pluginId);
    }

    final children = node['children'] ?? node['widgets'];
    if (children is List && children.isNotEmpty) {
      final kids = <Widget>[
        for (final c in children)
          if (c is Map)
            PackPaintTree(
              spec: Map<String, dynamic>.from(c),
              pluginId: pluginId,
              packSourceUrl: packSourceUrl,
              tabId: tabId,
            ),
      ];
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight) {
            return ListView(
              padding: EdgeInsets.zero,
              children: kids,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: kids,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
