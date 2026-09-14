import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/kit/slots/slots.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/blocks/catalog/catalog_body_block.dart';
import 'package:forja_foundation/blocks/catalog/columns_header_block.dart';
import 'package:forja_foundation/blocks/catalog/tabs_cards_block.dart';
import 'package:forja_foundation/blocks/catalog/top_body_block.dart';
import 'package:forja_foundation/blocks/details/details_block.dart';
import 'package:forja_foundation/blocks/details/match_details_block.dart';
import 'package:forja_foundation/blocks/empty/empty_block.dart';
import 'package:forja_foundation/blocks/search/catalog_search_page.dart';
import 'package:forja_foundation/blocks/shell/shell_block.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/layout_stack.dart';

/// Recursive validate+paint: pack node → foundation widget from props maps.
///
/// Slots (`hero`, `mood`, …) under [slots/]. Prebuilt blocks
/// (`catalogBody`, `details`, …) via `fromProps`. Cards/rails:
/// [PackPaintArtifact].
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

  static bool _isBlockType(String type) => switch (type) {
        'catalogBody' ||
        'columnsHeader' ||
        'topBody' ||
        'tabsCards' ||
        'search' ||
        'details' ||
        'matchDetails' ||
        'entryDetails' ||
        'shell' ||
        'empty' =>
          true,
        _ => false,
      };

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

    if (_isBlockType(type)) {
      return _paintBlock(context, spec, type: type);
    }

    final paint = spec['paint'];
    if (paint is Map) {
      final paintType = (paint['type'] ?? '').toString().trim();
      if (_isBlockType(paintType)) {
        return _paintBlock(context, spec, type: paintType);
      }
    }

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
        return PackTopBarSlot(spec: spec);
      case LayoutTypes.categoryBar:
        return PackCategoryBarSlot(spec: spec);
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
          if (_isBlockType(mergedType)) {
            return PackPaintTree(
              spec: merged,
              pluginId: pluginId,
              packSourceUrl: packSourceUrl,
              tabId: tabId,
            );
          }
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

  List<Widget> _paintChildren(BuildContext context, Map<String, dynamic> node) {
    final raw = node['children'] ?? node['widgets'] ?? node['items'];
    if (raw is! List) return const [];
    return [
      for (final c in raw)
        if (c is Map)
          PackPaintTree(
            spec: Map<String, dynamic>.from(c),
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          ),
    ];
  }

  Widget _paintBlock(
    BuildContext context,
    Map<String, dynamic> node, {
    required String type,
  }) {
    final paint = node['paint'];
    final propsRaw = paint is Map ? paint['props'] : node['props'];
    final props = propsRaw is Map
        ? Map<String, dynamic>.from(propsRaw)
        : <String, dynamic>{};
    final kids = _paintChildren(context, node);
    final body = kids.isEmpty
        ? const SizedBox.shrink()
        : kids.length == 1
            ? kids.first
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: kids,
              );
    final bg = ForjaShellColors.cinematic.menuSurface;

    switch (type) {
      case 'catalogBody':
        return CatalogBody.fromProps(props, sections: kids);
      case 'columnsHeader':
        return _paintColumnsHeader(context, node, props: props);
      case 'topBody':
        return _paintTopBody(context, node, props: props);
      case 'tabsCards':
        return _paintTabsCards(context, node, props: props);
      case 'search':
        return CatalogSearchPage.fromProps(props, results: body);
      case 'details':
        return DetailsBlock.fromProps(
          props,
          sections: kids,
          fallbackBackground: bg,
        );
      case 'matchDetails':
        return MatchDetailsPage.fromProps(
          props,
          belowActionRow: kids.isNotEmpty ? body : null,
          fallbackBackground: bg,
        );
      case 'entryDetails':
        return EntryDetails.fromProps(props, body: kids.isEmpty ? null : body);
      case 'shell':
        return ShellBlock.fromProps(
          props,
          topBar: kids.isNotEmpty ? kids.first : null,
          body: kids.length > 1
              ? (kids.length == 2
                  ? kids[1]
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: kids.sublist(1),
                    ))
              : body,
        );
      case 'empty':
        return EmptyBlock.fromProps(props);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _paintColumnsHeader(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
  }) {
    Widget? paintSlot(Object? raw) {
      if (raw is! Map) return null;
      return PackPaintTree(
        spec: Map<String, dynamic>.from(raw),
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
      );
    }

    var header = paintSlot(node['header']);
    var side = paintSlot(node['side']);
    var bodyW = paintSlot(node['body']);

    if (header == null || side == null || bodyW == null) {
      final kids = _paintChildren(context, node);
      header ??= kids.isNotEmpty ? kids[0] : null;
      side ??= kids.length > 1 ? kids[1] : null;
      bodyW ??= kids.length > 2
          ? kids[2]
          : (kids.length == 1 && header == null ? kids[0] : null);
    }

    return ColumnsHeaderBlock.fromProps(
      props,
      header: header,
      side: side,
      body: bodyW ?? const SizedBox.shrink(),
    );
  }

  Widget _paintTopBody(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
  }) {
    Widget? paintSlot(Object? raw) {
      if (raw is! Map) return null;
      return PackPaintTree(
        spec: Map<String, dynamic>.from(raw),
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
      );
    }

    var top = paintSlot(node['top'] ?? node['header']);
    var bodyTop = paintSlot(node['bodyTop'] ?? node['toolbar']);
    var grid = paintSlot(node['grid'] ?? node['body']);

    if (top == null || bodyTop == null || grid == null) {
      final kids = _paintChildren(context, node);
      top ??= kids.isNotEmpty ? kids[0] : null;
      bodyTop ??= kids.length > 1 ? kids[1] : null;
      grid ??= kids.length > 2
          ? kids[2]
          : (kids.length == 1 && top == null ? kids[0] : null);
    }

    return TopBodyBlock.fromProps(
      props,
      top: top,
      bodyTop: bodyTop,
      grid: grid ?? const SizedBox.shrink(),
    );
  }

  Widget _paintTabsCards(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
  }) {
    Widget? paintSlot(Object? raw) {
      if (raw is! Map) return null;
      return PackPaintTree(
        spec: Map<String, dynamic>.from(raw),
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
      );
    }

    var menu = paintSlot(node['menu']);
    var tabs = paintSlot(node['tabs']);
    var cards = paintSlot(node['cards'] ?? node['grid']);

    if (menu == null || tabs == null || cards == null) {
      final kids = _paintChildren(context, node);
      if (kids.length >= 3) {
        menu ??= kids[0];
        tabs ??= kids[1];
        cards ??= kids[2];
      } else if (kids.length == 2) {
        tabs ??= kids[0];
        cards ??= kids[1];
      } else if (kids.length == 1) {
        cards ??= kids[0];
      }
    }

    return TabsCardsBlock.fromProps(
      props,
      menu: menu,
      tabs: tabs,
      cards: cards ?? const SizedBox.shrink(),
    );
  }

  Widget _paintNode(BuildContext context, Map<String, dynamic> node) {
    final type = LayoutTypes.normalize(
      (node['type'] ?? '').toString(),
      node,
    );

    if (_isBlockType(type)) {
      return _paintBlock(context, node, type: type);
    }

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
      final paintType = (paint['type'] ?? '').toString().trim();
      if (_isBlockType(paintType)) {
        return _paintBlock(context, node, type: paintType);
      }
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

    if (node['items'] is List) {
      return PackListSlot(spec: node, pluginId: pluginId);
    }

    final kids = _paintChildren(context, node);
    if (kids.isNotEmpty) {
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
