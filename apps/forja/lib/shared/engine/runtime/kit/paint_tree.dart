import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/blocks/catalog/catalog_body_block.dart';
import 'package:forja_foundation/blocks/catalog/catalog_chrome.dart';
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
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/layout_stack.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';

/// Recursive validate+paint: pack node → foundation block / chrome / cards.
///
/// No per-section host painters. Packs emit blocks or `paint` props;
/// [PackLoadedPaint] runs opaque loads; [PackPaintArtifact] mounts cards.
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

    // Chrome + list. Section atoms (hero/mood/continue/because) → pack blocks.
    switch (type) {
      case LayoutTypes.verticalFilters:
        return const SizedBox.shrink();
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
          builder: (ctx, merged) => _paintList(ctx, merged),
        );
      case LayoutTypes.topBar:
        return _paintTopBar(context, spec);
      case LayoutTypes.categoryBar:
        return _paintCategoryBar(context, spec);
      case LayoutTypes.menu:
        return _paintMenu(context, spec);
      case LayoutTypes.tabs:
        return _paintTabs(context, spec);
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
          if (mergedType == LayoutTypes.row ||
              mergedType == 'rail' ||
              mergedType == 'ranked' ||
              mergedType == LayoutTypes.hero) {
            return PackPaintArtifact.posterRow(
              ctx,
              node: merged,
              pluginId: pluginId,
            );
          }
          if (mergedType == LayoutTypes.list || merged['items'] is List) {
            return _paintList(ctx, merged);
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
    final merged = Map<String, dynamic>.from(props);
    Widget? feedBody;
    final rawKids = node['children'] ?? node['widgets'];
    if (rawKids is List) {
      for (final c in rawKids) {
        if (c is! Map) continue;
        final child = Map<String, dynamic>.from(c);
        final t = LayoutTypes.normalize(
          (child['type'] ?? '').toString(),
          child,
        );
        if (t == LayoutTypes.topBar && merged['actions'] == null) {
          merged['actions'] = child['actions'];
          merged['title'] ??= child['title'] ?? child['label'];
        } else if (t == LayoutTypes.categoryBar) {
          merged['sideItems'] ??= child['items'];
          merged['selectedSideId'] ??= child['default'];
          merged['defaultSideId'] ??= child['default'];
        } else if (t == LayoutTypes.list || child['load'] != null) {
          feedBody = PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        }
      }
    }
    feedBody ??= () {
      final body = node['body'];
      if (body is Map) {
        return PackPaintTree(
          spec: Map<String, dynamic>.from(body),
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      }
      return null;
    }();

    final scope = LayoutScope.maybeOf(context);
    return ColumnsHeaderBlock.fromProps(
      merged,
      body: feedBody,
      actionSelections: scope == null
          ? const {}
          : {
              for (final a in (merged['actions'] is List
                  ? merged['actions'] as List
                  : const []))
                if (a is Map && (a['id'] ?? '').toString().isNotEmpty)
                  (a['id'] as Object).toString():
                      scope.selectedId((a['id'] as Object).toString()) ??
                          (a['default'] ?? '').toString(),
            },
      onActionSelect: (actionId, value) {
        scope?.onSelect(actionId, value, toggle: false);
      },
      onSideSelect: (id) {
        final barId = _childIdOfType(node, LayoutTypes.categoryBar) ?? 'cats';
        scope?.onSelect(barId, id, toggle: false);
      },
    );
  }

  Widget _paintTopBody(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
  }) {
    final merged = Map<String, dynamic>.from(props);
    Widget? feedGrid;
    final rawKids = node['children'] ?? node['widgets'];
    if (rawKids is List) {
      for (final c in rawKids) {
        if (c is! Map) continue;
        final child = Map<String, dynamic>.from(c);
        final t = LayoutTypes.normalize(
          (child['type'] ?? '').toString(),
          child,
        );
        if (t == LayoutTypes.topBar && merged['actions'] == null) {
          merged['actions'] = child['actions'];
          merged['title'] ??= child['title'] ?? child['label'];
        } else if (t == LayoutTypes.categoryBar) {
          merged['kindItems'] ??= child['items'];
          merged['selectedKindId'] ??= child['default'];
          merged['defaultKindId'] ??= child['default'];
        } else if (t == LayoutTypes.list || child['load'] != null) {
          feedGrid = PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        }
      }
    }

    final scope = LayoutScope.maybeOf(context);
    return TopBodyBlock.fromProps(
      merged,
      grid: feedGrid,
      onActionSelect: (actionId, value) {
        scope?.onSelect(actionId, value, toggle: false);
      },
      onKindSelect: (id) {
        final barId = _childIdOfType(node, LayoutTypes.categoryBar) ?? 'kind';
        scope?.onSelect(barId, id, toggle: false);
      },
    );
  }

  Widget _paintTabsCards(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
  }) {
    final merged = Map<String, dynamic>.from(props);
    Widget? feedCards;
    final rawKids = node['children'] ?? node['widgets'];
    if (rawKids is List) {
      for (final c in rawKids) {
        if (c is! Map) continue;
        final child = Map<String, dynamic>.from(c);
        final t = LayoutTypes.normalize(
          (child['type'] ?? '').toString(),
          child,
        );
        if (t == LayoutTypes.menu) {
          merged['menuItems'] ??= child['items'] ?? child['tabs'];
        } else if (t == LayoutTypes.tabs) {
          merged['tabItems'] ??= child['tabs'] ?? child['items'];
          merged['selectedTabId'] ??= child['default'];
          merged['defaultTabId'] ??= child['default'];
        } else if (t == LayoutTypes.list || child['load'] != null) {
          feedCards = PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        }
      }
    }

    final scope = LayoutScope.maybeOf(context);
    return TabsCardsBlock.fromProps(
      merged,
      cards: feedCards,
      onMenuSelect: (id) {
        final menuId = _childIdOfType(node, LayoutTypes.menu) ?? 'kind';
        scope?.onSelect(menuId, id, toggle: true);
      },
      onTabSelect: (id) {
        final tabsId = _childIdOfType(node, LayoutTypes.tabs) ?? 'status';
        scope?.onSelect(tabsId, id, toggle: false);
      },
    );
  }

  String? _childIdOfType(Map<String, dynamic> node, String type) {
    final raw = node['children'] ?? node['widgets'];
    if (raw is! List) return null;
    for (final c in raw) {
      if (c is! Map) continue;
      final child = Map<String, dynamic>.from(c);
      if (LayoutTypes.normalize((child['type'] ?? '').toString(), child) !=
          type) {
        continue;
      }
      final id = (child['id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    return null;
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
      return _paintList(context, node);
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
      return _paintList(context, node);
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

  /// kit.list items → foundation grid/list (expand-safe).
  Widget _paintList(BuildContext context, Map<String, dynamic> spec) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth < 1 ||
            constraints.maxHeight < 1) {
          return const SizedBox.shrink();
        }

        final raw = spec['items'];
        final items = <Map<String, dynamic>>[
          if (raw is List)
            for (final e in raw)
              if (e is Map) Map<String, dynamic>.from(e),
        ];
        final kindMenu = (spec['kindMenu'] ?? '').toString().trim();
        final kindFilter = kindMenu.isEmpty
            ? (spec['kind'] ?? '').toString().trim()
            : (LayoutScope.maybeOf(context)?.selectedId(kindMenu) ?? '').trim();
        final filtered = kindFilter.isEmpty || kindFilter == 'all'
            ? items
            : [
                for (final e in items)
                  if (_itemKind(e) == kindFilter) e,
              ];

        var style = (spec['style'] ?? 'grid').toString().trim().toLowerCase();
        if (style == 'epg' || style == 'guide') style = 'timeline';
        final cardKind =
            style == 'list' || style == 'timeline' ? 'event' : 'poster';

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: CatalogCardsGrid(
            items: filtered,
            cardKind: cardKind,
            emptyTitle: 'Nothing here yet.',
            onItemTap: (item) {
              final props = PackPaintArtifact.propsOf(item);
              final tap = PackPaintArtifact.openTap(
                context,
                pluginId: pluginId,
                props: props,
                open: item['open'],
                meta: item['meta'],
              );
              tap?.call();
            },
          ),
        );
      },
    );
  }

  String _itemKind(Map<String, dynamic> item) {
    final props = PackPaintArtifact.propsOf(item);
    final fromProps = (props['kind'] ?? '').toString().trim();
    if (fromProps.isNotEmpty) return fromProps;
    final direct = (item['kind'] ?? item['type'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final meta = item['meta'];
    if (meta is Map) {
      return (meta['type'] ?? meta['kind'] ?? '').toString().trim();
    }
    return '';
  }

  Widget _paintMenu(BuildContext context, Map<String, dynamic> spec) {
    final items = layoutItemsFromSpec(spec);
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final selected = scope?.selectedId(id);
    final toggle = spec['toggle'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ForjaShellChip(
              label: item.label,
              selected: selected == item.id,
              onTap: () => scope?.onSelect(id, item.id, toggle: toggle),
            ),
        ],
      ),
    );
  }

  Widget _paintTabs(BuildContext context, Map<String, dynamic> spec) {
    final items = layoutItemsFromSpec(spec);
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final selected = scope?.selectedId(id) ??
        (spec['default'] ?? items.first.id).toString();
    return CatalogChipBar(
      items: items,
      selectedId: selected,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      onSelect: (itemId) => scope?.onSelect(id, itemId, toggle: false),
    );
  }

  Widget _paintCategoryBar(BuildContext context, Map<String, dynamic> spec) {
    final items = layoutItemsFromSpec(spec);
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final selected = scope?.selectedId(id) ??
        (spec['default'] ?? items.first.id).toString();
    final orientation = (spec['orientation'] ?? spec['axis'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final vertical = orientation == 'vertical' ||
        orientation == 'rail' ||
        spec['vertical'] == true;
    if (vertical) {
      final width = (spec['width'] is num)
          ? (spec['width'] as num).toDouble()
          : 220.0;
      return CatalogSideRail(
        items: items,
        selectedId: selected,
        width: width,
        onSelect: (itemId) => scope?.onSelect(id, itemId, toggle: false),
      );
    }
    return CatalogChipBar(
      items: items,
      selectedId: selected,
      onSelect: (itemId) => scope?.onSelect(id, itemId, toggle: false),
    );
  }

  Widget _paintTopBar(BuildContext context, Map<String, dynamic> spec) {
    final scope = LayoutScope.maybeOf(context);
    final actions = propsActionMaps(spec);
    if (actions.isEmpty) {
      return CatalogTopChrome(
        actions: const [],
        title: (spec['title'] ?? spec['label'] ?? '').toString(),
      );
    }
    return CatalogTopChrome(
      actions: actions,
      title: (spec['title'] ?? spec['label'] ?? '').toString(),
      selections: {
        for (final a in actions)
          if ((a['id'] ?? '').toString().isNotEmpty)
            (a['id'] as Object).toString():
                scope?.selectedId((a['id'] as Object).toString()) ??
                    (a['default'] ?? '').toString(),
      },
      onSelect: (actionId, value) {
        scope?.onSelect(actionId, value, toggle: false);
      },
    );
  }
}
