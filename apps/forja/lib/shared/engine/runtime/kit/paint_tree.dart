import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/details/hero_pill_buttons.dart';
import 'package:forja/shared/engine/details/kit_list_status_button.dart';
import 'package:forja/shared/engine/details/kit_details_play.dart';
import 'package:forja/shared/engine/details/kit_list_entry.dart';
import 'package:forja/shared/engine/runtime/chrome/kit_schedule_window.dart';
import 'package:forja/shared/engine/runtime/chrome/portals_action_host.dart';
import 'package:forja/shared/engine/runtime/chrome/top_bar_host_hooks.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja_foundation/widgets/chrome/catalog_filter_sheet.dart';
import 'package:forja/shared/engine/runtime/kit/lazy_viewport_gate.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_open_mode.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/runtime/nav/open_catalog_search.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shared/engine/store/continue_entries.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja/shared/playback/open/history_playback_resume.dart';
import 'package:forja/shared/playback/play_resolve.dart';
import 'package:forja/shared/player/sources/resolve_panel_host.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/blocks/catalog/catalog_body_block.dart';
import 'package:forja_foundation/blocks/catalog/catalog_chrome.dart';
import 'package:forja_foundation/blocks/catalog/columns_header_block.dart';
import 'package:forja_foundation/blocks/catalog/tabs_cards_block.dart';
import 'package:forja_foundation/blocks/catalog/top_body_block.dart';
import 'package:forja_foundation/blocks/details/details_block.dart';
import 'package:forja_foundation/blocks/details/match_details_block.dart';
import 'package:forja_foundation/blocks/empty/empty_block.dart';
import 'package:forja_foundation/blocks/search/catalog_search_page.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/blocks/shell/shell_block.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/because_section.dart';
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';
import 'package:forja_foundation/widgets/catalog/shell_mood_circle.dart';
import 'package:forja_foundation/widgets/catalog/cinematic_hero.dart';
import 'package:forja_foundation/widgets/catalog/continue_section.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
import 'package:forja_foundation/widgets/catalog/mood_section.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/layout_stack.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:rust/rust.dart'
    show WatchHistoryService, canResumeFromSavedProgress;

/// One mount table: pack `{ type, props, children?, load? }` → foundation.
///
/// Prepared pages and small chrome types are the same catalog — packs compose
/// freely. Host only runs opaque [PackLoadedPaint] and injects callbacks.
class PackPaintTree extends StatelessWidget {
  const PackPaintTree({
    super.key,
    required this.spec,
    required this.pluginId,
    this.packSourceUrl,
    this.tabId,
    this.pageBottomChild,
  });

  final Map<String, dynamic> spec;
  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;

  /// Bleed rail tucked under a hero backdrop (Featured under Spotlight).
  final Widget? pageBottomChild;

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

    // Opaque load first — then remount merged node as the same type catalog.
    // continue / mood / because own host store or selection → handled in _mount.
    final load = packLoadSpec(spec['load']);
    if (load != null &&
        type != LayoutTypes.list &&
        type != LayoutTypes.continueWatching &&
        type != LayoutTypes.mood &&
        type != LayoutTypes.because) {
      final id = (spec['id'] ?? spec['rail'] ?? type).toString();
      final rail = (spec['rail'] ?? load.params['rail'] ?? '').toString();
      final chrome = PackChromeScope.maybeOf(context);
      final eager = type == LayoutTypes.hero ||
          (spec['bleed'] != null &&
              (spec['bleed'] as Object).toString().trim().isNotEmpty) ||
          (chrome?.isEagerLoad(id, rail: rail) ?? false) ||
          (chrome?.isPageFeedRail(rail) ?? false);
      final isHero = type == LayoutTypes.hero;
      final heroBleed = pageBottomChild != null;
      final heroH = isHero
          ? homeCinematicHeroBodyHeight(
              screenHeight: MediaQuery.sizeOf(context).height,
              compact: MediaQuery.sizeOf(context).width <
                  ShellTokens.heroDesktopMinBodyWidth,
              pageBottomBleed: heroBleed,
            )
          : 420.0;
      final skeleton = isHero
          ? homeCinematicHeroShimmer(height: heroH)
          : homeLoadingShimmer(
              homePosterRowSkeleton(topPadding: 12, titleWidth: 140),
            );
      return LazyViewportGate(
        detectorKey: Key('lazy-$pluginId-$id'),
        placeholderHeight: isHero ? heroH : 220,
        placeholder: skeleton,
        eager: eager,
        builder: (ctx) => PackLoadedPaint(
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
          action: load.action,
          params: load.params,
          fallbackSpec: spec,
          builder: (ctx2, merged) => PackPaintTree(
            spec: merged,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
            pageBottomChild: pageBottomChild,
          ),
        ),
      );
    }

    if (type == LayoutTypes.list) {
      final listLoad = packLoadSpec(spec['load']) ??
          (action: 'feed', params: <String, dynamic>{});
      return PackLoadedPaint(
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        tabId: tabId,
        action: listLoad.action,
        params: listLoad.params,
        fallbackSpec: spec,
        builder: (ctx, merged) => _mountList(ctx, merged),
      );
    }

    return _mount(context, spec, type: type);
  }

  List<Widget> _kids(BuildContext context, Map<String, dynamic> node) {
    final raw = node['children'] ?? node['widgets'];
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

  Map<String, dynamic> _propsOf(Map<String, dynamic> node) {
    final paint = node['paint'];
    final propsRaw = paint is Map ? paint['props'] : node['props'];
    if (propsRaw is Map) return Map<String, dynamic>.from(propsRaw);
    // Flat layout nodes (kit.topBar actions, kit.list items, …) are props.
    return Map<String, dynamic>.from(node)
      ..remove('type')
      ..remove('children')
      ..remove('widgets')
      ..remove('load')
      ..remove('paint');
  }

  Widget _mount(
    BuildContext context,
    Map<String, dynamic> node, {
    required String type,
  }) {
    final props = _propsOf(node);
    final kids = _kids(context, node);
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
    final scope = LayoutScope.maybeOf(context);

    switch (type) {
      case LayoutTypes.stack:
        return LayoutStack(
          spec: node,
          childBuilder: (child, _) => PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          ),
        );
      case LayoutTypes.verticalFilters:
        return const SizedBox.shrink();
      case LayoutTypes.topBar:
        return _chromeTopBar(context, node);
      case LayoutTypes.categoryBar:
        return _chromeCategoryBar(context, node);
      case LayoutTypes.menu:
        return _chromeMenu(context, node);
      case LayoutTypes.tabs:
        return _chromeTabs(context, node);
      case LayoutTypes.list:
        return _mountList(context, node);
      case LayoutTypes.row:
      case 'rail':
      case 'ranked':
        return PackPaintArtifact.posterRow(
          context,
          node: node,
          pluginId: pluginId,
        );
      case LayoutTypes.hero:
        return _mountHero(context, node);
      case LayoutTypes.mood:
        return _MoodMount(
          spec: node,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      case LayoutTypes.because:
        return _BecauseMount(
          spec: node,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl,
          tabId: tabId,
        );
      case LayoutTypes.continueWatching:
        return _ContinueMount(
          pluginId: pluginId,
          tabId: tabId,
          mergeHomeWatchHistory: node['mergeHomeWatchHistory'] == true,
        );
      case 'catalogBody':
        return CatalogBody.fromProps(props, sections: kids);
      case 'columnsHeader':
        return _mountColumnsHeader(context, node, props: props, scope: scope);
      case 'topBody':
        return _mountTopBody(context, node, props: props, scope: scope);
      case 'tabsCards':
        return _mountTabsCards(context, node, props: props, scope: scope);
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
    if (node['items'] is List) return _mountList(context, node);
    if (kids.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight) {
            return ListView(padding: EdgeInsets.zero, children: kids);
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

  Widget _mountColumnsHeader(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
    required LayoutScope? scope,
  }) {
    final chrome = PackChromeScope.maybeOf(context);
    final merged = Map<String, dynamic>.from(props);
    Widget? feed;
    Map<String, dynamic>? categoryChild;
    final rawKids = node['children'] ?? node['widgets'];
    if (rawKids is List) {
      for (final c in rawKids) {
        if (c is! Map) continue;
        final child = Map<String, dynamic>.from(c);
        final t = LayoutTypes.normalize((child['type'] ?? '').toString(), child);
        if (t == LayoutTypes.topBar) {
          merged['actions'] ??= child['actions'];
          merged['title'] ??= child['title'] ?? child['label'];
        } else if (t == LayoutTypes.categoryBar) {
          categoryChild = child;
          final barId = (child['id'] ?? 'cats').toString();
          final dynamicItems = chrome?.barItems(barId);
          if (dynamicItems != null && dynamicItems.isNotEmpty) {
            merged['sideItems'] = [
              for (final raw in dynamicItems)
                {
                  'id': (raw['id'] ?? '').toString(),
                  'label':
                      (raw['label'] ?? raw['title'] ?? raw['id'] ?? '').toString(),
                },
            ];
          } else {
            merged['sideItems'] ??= child['items'];
          }
          final live = scope?.selectedId(barId);
          merged['selectedSideId'] =
              (live != null && live.isNotEmpty) ? live : child['default'];
          merged['defaultSideId'] ??= child['default'];
          if (child['width'] != null) merged['sideWidth'] ??= child['width'];
          if (child['focusUp'] != null) merged['focusUp'] ??= child['focusUp'];
          if (child['focusDown'] != null) {
            merged['focusDown'] ??= child['focusDown'];
          }
        } else if (t == LayoutTypes.list || child['load'] != null) {
          feed = PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        }
      }
    }
    final actions = propsActionMaps(merged);
    return ColumnsHeaderBlock.fromProps(
      merged,
      body: feed,
      actionSelections: {
        for (final a in actions)
          if ((a['id'] ?? '').toString().isNotEmpty)
            (a['id'] as Object).toString():
                scope?.selectedId((a['id'] as Object).toString()) ??
                    (a['default'] ?? '').toString(),
      },
      actionSlots: _portalsActionSlots(context, actions: actions),
      wrapBody: _portalsWrapBody(context, actions: actions),
      onActionSelect: (actionId, value) {
        _dispatchTopBarAction(
          context,
          actions: actions,
          actionId: actionId,
          value: value,
          scope: scope,
        );
      },
      onSideSelect: (id) {
        final barId = (categoryChild?['id'] ??
                _childIdOfType(node, LayoutTypes.categoryBar) ??
                'cats')
            .toString();
        scope?.onSelect(barId, id, toggle: false);
      },
    );
  }

  Widget _mountTopBody(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
    required LayoutScope? scope,
  }) {
    final chrome = PackChromeScope.maybeOf(context);
    final merged = Map<String, dynamic>.from(props);
    Widget? feed;
    Map<String, dynamic>? categoryChild;
    final rawKids = node['children'] ?? node['widgets'];
    if (rawKids is List) {
      for (final c in rawKids) {
        if (c is! Map) continue;
        final child = Map<String, dynamic>.from(c);
        final t = LayoutTypes.normalize((child['type'] ?? '').toString(), child);
        if (t == LayoutTypes.topBar) {
          merged['actions'] ??= child['actions'];
          merged['title'] ??= child['title'] ?? child['label'];
        } else if (t == LayoutTypes.categoryBar) {
          categoryChild = child;
          final barId = (child['id'] ?? 'kind').toString();
          final dynamicItems = chrome?.barItems(barId);
          if (dynamicItems != null && dynamicItems.isNotEmpty) {
            merged['kindItems'] = [
              for (final raw in dynamicItems)
                {
                  'id': (raw['id'] ?? '').toString(),
                  'label':
                      (raw['label'] ?? raw['title'] ?? raw['id'] ?? '').toString(),
                  if (raw['icon'] != null) 'icon': raw['icon'],
                },
            ];
          } else {
            merged['kindItems'] ??= child['items'];
          }
          final live = scope?.selectedId(barId);
          merged['selectedKindId'] =
              (live != null && live.isNotEmpty) ? live : child['default'];
          merged['defaultKindId'] ??= child['default'];
        } else if (t == LayoutTypes.list || child['load'] != null) {
          feed = PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        }
      }
    }
    final actions = propsActionMaps(merged);
    final actionSelections = _topBarSelections(scope, actions);
    final barId = (categoryChild?['id'] ?? 'kind').toString();
    final useCircles = categoryChild != null &&
        (categoryChild['kindIcons'] is Map ||
            (categoryChild['source'] ?? '').toString() == 'live_schedule');
    final kindsBar = useCircles
        ? _kindCircleBar(
            context,
            barId: barId,
            items: _kindItemsWithIcons(
              merged['kindItems'] is List
                  ? merged['kindItems'] as List
                  : const [],
              kindIcons: kitCategoryBarKindIcons(categoryChild),
            ),
            selectedId: (merged['selectedKindId'] ??
                    merged['defaultKindId'] ??
                    'all')
                .toString(),
            onSelect: (id) => scope?.onSelect(barId, id, toggle: false),
            focusDown: categoryChild['focusDown']?.toString(),
          )
        : null;
    return TopBodyBlock.fromProps(
      merged,
      grid: feed,
      kindsBar: kindsBar,
      actionSelections: actionSelections,
      actionSelectionLabels: _topBarSelectionLabels(actionSelections, actions),
      actionSlots: _portalsActionSlots(context, actions: actions),
      wrapBody: _portalsWrapBody(context, actions: actions),
      onActionSelect: (actionId, value) {
        _dispatchTopBarAction(
          context,
          actions: actions,
          actionId: actionId,
          value: value,
          scope: scope,
        );
      },
      onKindSelect: (id) {
        scope?.onSelect(barId, id, toggle: false);
      },
    );
  }

  Widget _mountTabsCards(
    BuildContext context,
    Map<String, dynamic> node, {
    required Map<String, dynamic> props,
    required LayoutScope? scope,
  }) {
    final merged = Map<String, dynamic>.from(props);
    Widget? feed;
    String menuId = 'kind';
    String tabsId = 'status';
    final rawKids = node['children'] ?? node['widgets'];
    if (rawKids is List) {
      for (final c in rawKids) {
        if (c is! Map) continue;
        final child = Map<String, dynamic>.from(c);
        final t = LayoutTypes.normalize((child['type'] ?? '').toString(), child);
        if (t == LayoutTypes.menu) {
          menuId = (child['id'] ?? 'kind').toString();
          merged['menuItems'] ??= child['items'] ?? child['tabs'];
          final live = scope?.selectedId(menuId);
          if (live != null && live.isNotEmpty) {
            merged['selectedMenuId'] = live;
          }
        } else if (t == LayoutTypes.tabs) {
          tabsId = (child['id'] ?? 'status').toString();
          merged['tabItems'] ??= child['tabs'] ?? child['items'];
          final live = scope?.selectedId(tabsId);
          merged['selectedTabId'] =
              (live != null && live.isNotEmpty) ? live : child['default'];
          merged['defaultTabId'] ??= child['default'];
        } else if (t == LayoutTypes.list || child['load'] != null) {
          feed = PackPaintTree(
            spec: child,
            pluginId: pluginId,
            packSourceUrl: packSourceUrl,
            tabId: tabId,
          );
        }
      }
    }
    return TabsCardsBlock.fromProps(
      merged,
      cards: feed,
      onMenuSelect: (id) {
        scope?.onSelect(menuId, id, toggle: true);
      },
      onTabSelect: (id) {
        scope?.onSelect(tabsId, id, toggle: false);
      },
    );
  }

  List<({String id, String label, String? icon})> _kindItemsWithIcons(
    List raw, {
    required Map<String, String> kindIcons,
  }) {
    final out = <({String id, String label, String? icon})>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final id = (e['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final label = (e['label'] ?? e['title'] ?? id).toString();
      final iconToken = (e['icon'] ?? kindIcons[id.toLowerCase()])?.toString();
      out.add((id: id, label: label, icon: iconToken));
    }
    return out;
  }

  Widget _kindCircleBar(
    BuildContext context, {
    required String barId,
    required List<({String id, String label, String? icon})> items,
    required String selectedId,
    required ValueChanged<String> onSelect,
    String? focusDown,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final layout =
        tv ? ShellMoodCircleLayout.tvScrollable : ShellMoodCircleLayout.desktop;
    final down = focusDown?.trim() ?? '';
    return SizedBox(
      key: ValueKey('kind-circles-$barId'),
      height: layout.rowHeight,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          top: 2,
          bottom: 10,
          left: ShellTokens.compactChromeLeadingInset(context),
          right: ShellTokens.bodyHorizontalPadding,
        ),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(width: layout.horizontalGap),
                  Builder(
                    builder: (context) {
                      final item = items[i];
                      final meta =
                          kitMoodCircleMeta(id: item.id, icon: item.icon);
                      final on = selectedId == item.id;
                      return ShellMoodCircleItem(
                        layout: layout,
                        label: catalogKitCategoryLabel(
                          item.id,
                          label: item.label,
                        ),
                        icon: meta.icon,
                        accent: meta.accent,
                        selected: on,
                        listIndex: i,
                        tvTabId: tabId,
                        tvRowId: barId,
                        onDownEdge: down.isEmpty
                            ? null
                            : () => scope?.resolveFocusEdge(down)?.call(),
                        onTap: () {
                          onSelect(item.id);
                          if (down.isNotEmpty) {
                            scope?.resolveFocusEdge(down)?.call();
                          }
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dispatchTopBarAction(
    BuildContext context, {
    required List<Map<String, dynamic>> actions,
    required String actionId,
    required String value,
    required LayoutScope? scope,
  }) {
    final chrome = PackChromeScope.maybeOf(context);
    final action = actions.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a != null && (a['id'] ?? '').toString() == actionId,
          orElse: () => null,
        );
    final verb =
        (action?['action'] ?? actionId).toString().trim().toLowerCase();
    if (verb == 'refresh' || actionId == 'refresh') {
      chrome?.onBumpRefresh();
      return;
    }
    if (verb == 'eventsearch' || verb == 'search' || actionId == 'search') {
      unawaited(_openEventSearch(context, action ?? const {}));
      return;
    }
    if (verb == 'portals' || actionId == 'portals') {
      final hoist =
          (action?['hoistSource'] ?? action?['source'] ?? '').toString();
      if (hoist.isNotEmpty) {
        PortalsActionHost.registerHoistSource(hoist);
      }
      final key = (tabId ?? '').trim();
      if (key.isEmpty) {
        ForjaToast.show('Portals unavailable');
        return;
      }
      try {
        final container = ProviderScope.containerOf(context);
        final open = container.read(portalsPanelOpenProvider(key));
        container.read(portalsPanelOpenProvider(key).notifier).state = !open;
        if (!open) {
          container.invalidate(portalsInventoryProvider(key));
        }
      } catch (_) {
        ForjaToast.show('Portals unavailable');
      }
      return;
    }
    if (value == '__open__') {
      unawaited(
        _openTopBarMenuSheet(
          context,
          action: action ?? const {},
          actionId: actionId,
          scope: scope,
        ),
      );
      return;
    }
    if (actionId == 'view' || verb == 'view') {
      chrome?.onViewStyle(value);
    }
    scope?.onSelect(actionId, value, toggle: false);
    _persistTopBarChromePref(
      context,
      actionId: actionId,
      value: value,
      action: action,
    );
  }

  /// Live host prefs only — gate on pack flags, never bare action ids
  /// (`catalog` / `horizon` are reused by other hubs with static menus).
  void _persistTopBarChromePref(
    BuildContext context, {
    required String actionId,
    required String value,
    Map<String, dynamic>? action,
  }) {
    final tab = (tabId ?? '').trim();
    if (tab.isEmpty || value.isEmpty) return;
    final key = kitChromeKeyForTab(tab);
    if (key.isEmpty) return;
    try {
      final container = ProviderScope.containerOf(context);
      if (action?['dynamicCatalogs'] == true) {
        container.read(kitFeedCatalogFilterProvider(key).notifier).state =
            value;
        unawaited(
          KitTopBarHostHooks.writeCatalogFilter?.call(
                context,
                value,
                tabId: tab,
              ) ??
              Future.value(),
        );
      } else if (action?['dynamicSchedule'] == true) {
        container.read(kitFeedHorizonPrefProvider(key).notifier).state = value;
      }
    } catch (_) {}
  }

  Future<void> _openTopBarMenuSheet(
    BuildContext context, {
    required Map<String, dynamic> action,
    required String actionId,
    required LayoutScope? scope,
  }) async {
    final current = (scope?.selectedId(actionId) ??
            (action['default'] ?? '').toString())
        .trim();
    // Live Sports only — never treat every `id: catalog` / schedule id as
    // host product (other hubs may reuse those ids with static items).
    final dynamicCatalog = action['dynamicCatalogs'] == true;
    final dynamicSchedule = action['dynamicSchedule'] == true;

    if (dynamicSchedule) {
      final opener = KitTopBarHostHooks.openScheduleSheet;
      if (opener != null) {
        await opener(
          context,
          currentPref: current.isEmpty ? kKitScheduleDefaultPref : current,
          onChanged: (pref) {
            if (!context.mounted) return;
            scope?.onSelect(actionId, pref, toggle: false);
            _persistTopBarChromePref(
              context,
              actionId: actionId,
              value: pref,
              action: action,
            );
          },
        );
        return;
      }
    }

    if (dynamicCatalog) {
      var options = <({String id, String label, String? subtitle})>[
        for (final e in propsIdLabelList(action, 'items'))
          (id: e.id, label: e.label, subtitle: null),
      ];
      final loader = KitTopBarHostHooks.loadCatalogOptions;
      if (loader != null) {
        final dynamicOpts = await loader();
        if (!context.mounted) return;
        if (dynamicOpts.isNotEmpty) {
          options = [
            (id: 'all', label: 'All', subtitle: null),
            for (final o in dynamicOpts)
              if (o.id != 'all')
                (id: o.id, label: o.label, subtitle: null),
          ];
        }
      }
      final opener = KitTopBarHostHooks.openCatalogSheet;
      final picked = opener != null
          ? await opener(
              context,
              current: current.isEmpty ? 'all' : current,
              options: options,
            )
          : await showCatalogFilterSheet(
              context,
              current: current.isEmpty ? 'all' : current,
              options: options,
            );
      if (picked == null || !context.mounted) return;
      scope?.onSelect(actionId, picked, toggle: false);
      _persistTopBarChromePref(
        context,
        actionId: actionId,
        value: picked,
        action: action,
      );
      return;
    }

    final nested = propsIdLabelList(action, 'items');
    if (nested.isEmpty) return;
    final picked = await showCatalogFilterSheet(
      context,
      current: current.isEmpty ? nested.first.id : current,
      options: [
        for (final e in nested) (id: e.id, label: e.label, subtitle: null),
      ],
    );
    if (picked == null || !context.mounted) return;
    scope?.onSelect(actionId, picked, toggle: false);
    _persistTopBarChromePref(
      context,
      actionId: actionId,
      value: picked,
      action: action,
    );
  }

  Map<String, Widget> _portalsActionSlots(
    BuildContext context, {
    required List<Map<String, dynamic>> actions,
  }) {
    final tab = (tabId ?? '').trim();
    if (tab.isEmpty) return const {};
    Map<String, dynamic>? portalsAction;
    for (final a in actions) {
      final id = (a['id'] ?? '').toString();
      final verb = (a['action'] ?? id).toString().toLowerCase();
      if (id == 'portals' || verb == 'portals') {
        portalsAction = a;
        break;
      }
    }
    if (portalsAction == null) return const {};
    final hoist = (portalsAction['hoistSource'] ??
            portalsAction['source'] ??
            '')
        .toString();
    return {
      'portals': Consumer(
        builder: (ctx, ref, _) => PortalsActionHost.buildPortalsChip(
          ctx,
          ref,
          tabId: tab,
          rowId: 'portals',
          itemIndex: 0,
          action: {
            if (hoist.isNotEmpty) 'hoistSource': hoist,
          },
        ),
      ),
    };
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

  Widget _mountHero(BuildContext context, Map<String, dynamic> node) {
    final items = node['items'];
    if (items is! List || items.isEmpty) return const SizedBox.shrink();
    final slides = <CinematicHeroSlide>[];
    final slideMetas = <MetaItem?>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      if (slides.length >= 5) break;
      final item = Map<String, dynamic>.from(raw);
      final props = PackPaintArtifact.propsOf(item);
      final meta = item['meta'] is Map
          ? MetaItem.fromJson(Map<String, dynamic>.from(item['meta'] as Map))
          : null;
      final open = item['open'] is Map
          ? MetaOpen.fromJson(Map<String, dynamic>.from(item['open'] as Map))
          : meta?.open;
      final title = (props['title'] ?? meta?.name ?? '').toString().trim();
      final backdrop = (props['backdropUrl'] ??
              props['backgroundUrl'] ??
              meta?.background ??
              '')
          .toString()
          .trim();
      final poster = (props['posterUrl'] ??
              props['imageUrl'] ??
              meta?.poster ??
              '')
          .toString()
          .trim();
      if (title.isEmpty && backdrop.isEmpty && poster.isEmpty) continue;
      final id = (open?.id ?? meta?.id ?? props['id'] ?? title).toString();
      slides.add(
        CinematicHeroSlide(
          id: id.isEmpty ? title : id,
          title: title.isEmpty ? 'Title' : title,
          backdropUrl: backdrop.isNotEmpty ? backdrop : poster,
          posterUrl: poster.isEmpty ? null : poster,
          logoUrl: (props['logoUrl'] ?? props['logo'] ?? meta?.logo ?? '')
              .toString(),
          overview: (props['overview'] ??
                  props['description'] ??
                  meta?.description ??
                  '')
              .toString(),
          rating: props['rating'] is num
              ? (props['rating'] as num).toDouble()
              : meta?.rating,
          year: () {
            final y = (props['year'] ?? meta?.releaseInfo ?? '').toString();
            return y.isEmpty ? null : y.split(' • ').first;
          }(),
          badge: (props['badge'] ?? meta?.badge)?.toString(),
          genres: props['genres'] is List
              ? [
                  for (final g in props['genres'] as List)
                    if (g != null && g.toString().trim().isNotEmpty)
                      g.toString(),
                ]
              : (meta?.genres ?? const <String>[]),
          onDetails: PackPaintArtifact.openTap(
            context,
            pluginId: pluginId,
            props: props,
            open: open?.toJson(),
            meta: meta?.toJson(),
          ),
        ),
      );
      slideMetas.add(meta);
    }
    if (slides.isEmpty) return const SizedBox.shrink();
    final compact = MediaQuery.sizeOf(context).width <
        ShellTokens.heroDesktopMinBodyWidth;
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final scope = LayoutScope.maybeOf(context);
    final bleed = (node['bleed'] ?? '').toString().trim();
    final focusDown = bleed.isNotEmpty
        ? scope?.resolveFocusEdge(bleed)
        : scope?.resolveFocusEdge((node['focusDown'] ?? '').toString());
    final tv = policy.useFocusableMoodChips;
    final tab = (tabId ?? scope?.tabId ?? '').trim();

    return CinematicHero(
      slides: slides,
      pageBottomChild: pageBottomChild,
      layout: CinematicHeroLayout(
        compact: compact,
        tvDensity: metrics.usesTvDensity,
        kenBurns: policy.kenBurnsBackdrop,
        plainTitle: policy.useFocusableMoodChips,
        heroMinTitleHeight: metrics.heroMinTitleHeight,
        heroActionUseFittedBox: metrics.heroActionUseFittedBox,
        heroCompactRightInset: metrics.heroCompactRightInset,
        sectionHorizontalPadding: ShellTokens.homeSectionHorizontalPadding,
        heroHeightFraction: compact
            ? ShellTokens.heroHeightFractionCompact
            : ShellTokens.heroHeightFractionDesktop,
        firstCatalogRowHeight: pageBottomChild == null
            ? 0
            : ShellTokens.homeSectionTitleTop + 180 + 40,
      ),
      onHeight: tab.isEmpty
          ? null
          : (h) {
              ShellBus.hubHeroHeightFor(tab).value = h;
            },
      actionRowBuilder: (ctx, slide, {required isActive}) {
        if (!isActive) return const SizedBox.shrink();
        final idx = slides.indexWhere((s) => s.id == slide.id);
        final meta = idx >= 0 && idx < slideMetas.length ? slideMetas[idx] : null;
        final details = slide.onDetails;
        final follow = meta == null
            ? null
            : ListFollowTarget.fromMeta(meta: meta, pluginId: pluginId);
        final detailsBtn = details == null
            ? null
            : HeroPillPlayButton(
                label: 'View details',
                icon: Icons.info_outline_rounded,
                tone: HeroPillPlayTone.primary,
                alwaysShowLabel: true,
                onTap: details,
                autoFocus: tv && policy.heroPlayAutoFocus,
                tvTabId: tab.isEmpty ? null : tab,
                tvRowId: 'hero-details',
              );
        final pin = follow == null
            ? null
            : KitListStatusButton.follow(
                followTarget: follow,
                excludeFromTvTraversal: false,
              );
        final row = Row(
          children: [
            if (detailsBtn != null) detailsBtn,
            if (pin != null) ...[
              if (detailsBtn != null) const SizedBox(width: 12),
              pin,
            ],
          ],
        );
        if (!tv || focusDown == null) return row;
        return Focus(
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              focusDown();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: row,
        );
      },
    );
  }

  Widget _mountList(BuildContext context, Map<String, dynamic> spec) {
    final openSetting = (spec['openSetting'] ?? '').toString().trim();
    if (openSetting.isEmpty) {
      return _mountListBody(context, spec);
    }
    return _ListOpenSettingGate(
      pluginId: pluginId,
      openSettingId: openSetting,
      layoutOpen: (spec['open'] ?? '').toString(),
      builder: (effectiveOpen) {
        final merged = Map<String, dynamic>.from(spec)..['open'] = effectiveOpen;
        return _mountListBody(context, merged);
      },
    );
  }

  Widget _mountListBody(BuildContext context, Map<String, dynamic> spec) {
    final chrome = PackChromeScope.maybeOf(context);
    final selection = chrome?.selectedListItem;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth < 1 ||
            constraints.maxHeight < 1) {
          return const SizedBox.shrink();
        }
        Widget buildBody(Map<String, dynamic>? selected) {
          final raw = spec['items'];
          final items = <Map<String, dynamic>>[
            if (raw is List)
              for (final e in raw)
                if (e is Map) Map<String, dynamic>.from(e),
          ];
          final kindMenu = (spec['kindMenu'] ?? '').toString().trim();
          final kindFilter = kindMenu.isEmpty
              ? (spec['kind'] ?? '').toString().trim()
              : (LayoutScope.maybeOf(context)?.selectedId(kindMenu) ?? '')
                  .trim();
          final filtered = kindFilter.isEmpty || kindFilter == 'all'
              ? items
              : [
                  for (final e in items)
                    if (_itemKind(e).toLowerCase() ==
                            kindFilter.toLowerCase() ||
                        _itemKind(e)
                            .toLowerCase()
                            .contains(kindFilter.toLowerCase()))
                      e,
                ];
          var style = (spec['style'] ?? 'grid').toString().trim().toLowerCase();
          final viewOverride = (chrome?.viewStyle ??
                  LayoutScope.maybeOf(context)?.selectedId('view') ??
                  '')
              .toString()
              .trim()
              .toLowerCase();
          if (viewOverride.isNotEmpty) {
            if (viewOverride == 'cards' ||
                viewOverride == 'list' ||
                viewOverride == 'timeline' ||
                viewOverride == 'epg' ||
                viewOverride == 'guide') {
              style = viewOverride;
            }
          }
          if (style == 'epg' || style == 'guide') style = 'timeline';
          final cardKind = () {
            if (style == 'list' || style == 'timeline') return 'dense';
            if (style == 'cards') return 'event';
            if (style == 'grid') {
              return _itemsLookLikeEvents(filtered) ? 'event' : 'poster';
            }
            return 'poster';
          }();
          final openMode = (spec['open'] ?? '').toString().trim().toLowerCase();
          final selectedId = selected == null
              ? null
              : (selected['id'] ??
                      (selected['meta'] is Map
                          ? (selected['meta'] as Map)['id']
                          : null) ??
                      '')
                  .toString();
          final wide = constraints.maxWidth >= 900;
          final showPanel = openMode == 'panel' && selected != null && wide;

          final grid = CatalogCardsGrid(
            items: filtered,
            cardKind: cardKind,
            selectedItemId: selectedId,
            emptyTitle: (spec['emptyTitle'] ?? 'Nothing here yet.').toString(),
            emptyDescription:
                (spec['emptyDescription'] ?? '').toString().isEmpty
                    ? null
                    : spec['emptyDescription']?.toString(),
            onItemTap: (item) {
              if (openMode == 'panel') {
                chrome?.onSelectListItem(item);
                return;
              }
              PackPaintArtifact.openTap(
                context,
                pluginId: pluginId,
                props: PackPaintArtifact.propsOf(item),
                open: item['open'],
                meta: item['meta'],
              )?.call();
            },
          );

          Widget body = SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: grid,
          );

          if (showPanel) {
            final entry = _listEntryFromItem(selected);
            final panel = KitResolvePanelHost.instance.buildSidePanel(
              context: context,
              entry: entry,
              layoutWidgets: [
                if (spec['panelTabs'] is List)
                  {
                    'type': 'kit.list',
                    'panelTabs': spec['panelTabs'],
                    'panelTab': spec['panelTab'],
                  },
              ],
              shellTabVisible: chrome?.shellTabVisible ?? true,
              refreshEpoch: chrome?.refreshEpoch ?? 0,
              onClosed: () => chrome?.onSelectListItem(null),
            );
            body = SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 60, child: grid),
                  Expanded(flex: 40, child: panel),
                ],
              ),
            );
          }

          final hoist = _hoistSourceFromPage(context);
          if (hoist != null && (tabId ?? '').isNotEmpty) {
            // Composition roots (columnsHeader / topBody) already wrap below the
            // top bar. Avoid nested SidePanelOverlay when those are present.
            final scope = LayoutScope.maybeOf(context);
            final underComposition = scope?.widgetSpecs.values.any((spec) {
                  final t = LayoutTypes.normalize(
                    (spec['type'] ?? '').toString(),
                    spec,
                  );
                  return t == 'columnsHeader' || t == 'topBody';
                }) ??
                false;
            if (!underComposition) {
              return PortalsActionHost.wrapListBody(
                context,
                tabId: tabId!,
                sourceId: hoist,
                shellTabVisible: chrome?.shellTabVisible ?? true,
                child: body,
              );
            }
          }
          return body;
        }

        if (selection == null) return buildBody(null);
        return ListenableBuilder(
          listenable: selection,
          builder: (context, _) => buildBody(selection.value),
        );
      },
    );
  }

  KitListEntry _listEntryFromItem(Map<String, dynamic> item) {
    final metaMap = item['meta'] is Map
        ? Map<String, dynamic>.from(item['meta'] as Map)
        : <String, dynamic>{
            'id': (item['id'] ?? PackPaintArtifact.propsOf(item)['id'] ?? '')
                .toString(),
            'type': (item['type'] ?? 'other').toString(),
            'name': (PackPaintArtifact.propsOf(item)['title'] ??
                    item['name'] ??
                    '')
                .toString(),
          };
    final meta = MetaItem.fromJson(metaMap);
    return KitListEntry(
      meta: meta,
      legacyRow: Map<String, dynamic>.from(item),
      kind: _itemKind(item),
      pluginId: pluginId,
    );
  }

  String? _hoistSourceFromPage(BuildContext context) {
    final scope = LayoutScope.maybeOf(context);
    final specs = scope?.widgetSpecs.values ?? const [];
    for (final spec in specs) {
      final hoist = _hoistSourceFromActions(propsActionMaps(spec));
      if (hoist != null) return hoist;
    }
    return null;
  }

  String? _hoistSourceFromActions(List<Map<String, dynamic>> actions) {
    for (final a in actions) {
      final verb = (a['action'] ?? a['id'] ?? '').toString().trim().toLowerCase();
      if (verb != 'portals') continue;
      final hoist =
          (a['hoistSource'] ?? a['source'] ?? '').toString().trim();
      if (hoist.isNotEmpty) return hoist;
    }
    return null;
  }

  /// Portals panel below top bar — independent of feed load / list paint.
  Widget Function(Widget body)? _portalsWrapBody(
    BuildContext context, {
    required List<Map<String, dynamic>> actions,
  }) {
    final hoist = _hoistSourceFromActions(actions);
    final tab = (tabId ?? '').trim();
    if (hoist == null || tab.isEmpty) return null;
    PortalsActionHost.registerHoistSource(hoist);
    final chrome = PackChromeScope.maybeOf(context);
    return (child) => PortalsActionHost.wrapListBody(
          context,
          tabId: tab,
          sourceId: hoist,
          shellTabVisible: chrome?.shellTabVisible ?? true,
          child: child,
        );
  }

  String _itemKind(Map<String, dynamic> item) {
    final props = PackPaintArtifact.propsOf(item);
    for (final key in [
      item['categoryId'],
      item['kind'],
      props['kind'],
      props['categoryId'],
      item['category'],
      item['sport'],
      if (item['meta'] is Map) (item['meta'] as Map)['kind'],
      if (item['meta'] is Map) (item['meta'] as Map)['categoryId'],
    ]) {
      final v = (key ?? '').toString().trim();
      if (v.isNotEmpty &&
          v != 'live_match' &&
          v != 'iptv' &&
          v != 'movie' &&
          v != 'tv') {
        return v;
      }
    }
    return '';
  }

  bool _itemsLookLikeEvents(List<Map<String, dynamic>> items) {
    for (final item in items.take(8)) {
      final paint = item['paint'];
      final type = paint is Map ? (paint['type'] ?? '').toString() : '';
      if (type == 'eventCard' || type == 'event') return true;
      final props = PackPaintArtifact.propsOf(item);
      if (props['homeTeam'] != null ||
          props['awayTeam'] != null ||
          props['live'] == true) {
        return true;
      }
    }
    return false;
  }

  Widget _chromeMenu(BuildContext context, Map<String, dynamic> spec) {
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

  Widget _chromeTabs(BuildContext context, Map<String, dynamic> spec) {
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

  Widget _chromeCategoryBar(BuildContext context, Map<String, dynamic> spec) {
    final chrome = PackChromeScope.maybeOf(context);
    final id = (spec['id'] ?? '').toString();
    final dynamicItems = chrome?.barItems(id);
    final kindIcons = kitCategoryBarKindIcons(spec);
    final seed = layoutItemsFromSpec(spec);
    final items = <({String id, String label, String? icon})>[
      if (dynamicItems != null && dynamicItems.isNotEmpty)
        for (final raw in dynamicItems)
          (
            id: (raw['id'] ?? '').toString(),
            label: (raw['label'] ?? raw['title'] ?? raw['id'] ?? '').toString(),
            icon: (raw['icon'] ?? kindIcons[(raw['id'] ?? '').toString().toLowerCase()])
                ?.toString(),
          )
      else
        for (final s in seed)
          (
            id: s.id,
            label: s.label,
            icon: kindIcons[s.id.toLowerCase()],
          ),
    ].where((e) => e.id.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.maybeOf(context);
    final selected = scope?.selectedId(id) ??
        (spec['default'] ?? items.first.id).toString();
    final orientation = (spec['orientation'] ?? spec['axis'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final source = (spec['source'] ?? '').toString().trim().toLowerCase();
    final vertical = orientation == 'vertical' ||
        orientation == 'rail' ||
        spec['vertical'] == true ||
        source == 'iptv';
    final useCircles =
        spec['kindIcons'] is Map || source == 'live_schedule';
    if (useCircles && !vertical) {
      return _kindCircleBar(
        context,
        barId: id,
        items: items,
        selectedId: selected,
        onSelect: (itemId) => scope?.onSelect(id, itemId, toggle: false),
        focusDown: spec['focusDown']?.toString(),
      );
    }
    if (vertical) {
      final width =
          (spec['width'] is num) ? (spec['width'] as num).toDouble() : 220.0;
      return CatalogSideRail(
        items: [for (final e in items) (id: e.id, label: e.label)],
        selectedId: selected,
        width: width,
        onSelect: (itemId) => scope?.onSelect(id, itemId, toggle: false),
      );
    }
    return CatalogChipBar(
      items: [for (final e in items) (id: e.id, label: e.label)],
      selectedId: selected,
      onSelect: (itemId) => scope?.onSelect(id, itemId, toggle: false),
    );
  }

  Map<String, String> _topBarSelections(
    LayoutScope? scope,
    List<Map<String, dynamic>> actions,
  ) {
    final out = <String, String>{};
    for (final a in actions) {
      final id = (a['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      var selected =
          (scope?.selectedId(id) ?? (a['default'] ?? '').toString()).trim();
      // Live dynamic menus — defaults only when pack opts in. Static menus keep
      // pack `default` / first item (do not force by action id).
      if (a['dynamicCatalogs'] == true && selected.isEmpty) selected = 'all';
      if (a['dynamicSchedule'] == true && selected.isEmpty) {
        selected = kKitScheduleDefaultPref;
      }
      out[id] = selected;
    }
    return out;
  }

  Map<String, String> _topBarSelectionLabels(
    Map<String, String> selections,
    List<Map<String, dynamic>> actions,
  ) {
    final out = <String, String>{};
    for (final a in actions) {
      final id = (a['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final selected = (selections[id] ?? '').trim();
      // Host chip labels are Live Sports only — static menus use pack items.
      if (a['dynamicCatalogs'] == true) {
        final label = KitTopBarHostHooks.catalogChipLabel?.call(
          selected.isEmpty ? 'all' : selected,
          const [],
        );
        if (label != null && label.isNotEmpty) out[id] = label;
      } else if (a['dynamicSchedule'] == true) {
        final label = KitTopBarHostHooks.scheduleChipLabel?.call(
          selected.isEmpty ? kKitScheduleDefaultPref : selected,
        );
        if (label != null && label.isNotEmpty) out[id] = label;
      }
    }
    return out;
  }

  Widget _chromeTopBar(BuildContext context, Map<String, dynamic> spec) {
    final scope = LayoutScope.maybeOf(context);
    final actions = propsActionMaps(spec);
    final selections = _topBarSelections(scope, actions);
    return CatalogTopChrome(
      actions: actions,
      title: (spec['title'] ?? spec['label'] ?? '').toString(),
      actionSlots: _portalsActionSlots(context, actions: actions),
      selections: selections,
      selectionLabels: _topBarSelectionLabels(selections, actions),
      onSelect: (actionId, value) {
        _dispatchTopBarAction(
          context,
          actions: actions,
          actionId: actionId,
          value: value,
          scope: scope,
        );
      },
    );
  }

  Future<void> _openEventSearch(
    BuildContext context,
    Map<String, dynamic> action,
  ) async {
    final chrome = PackChromeScope.maybeOf(context);
    final hint = (action['placeholder'] ?? action['hint'] ?? 'Search…')
        .toString()
        .trim();
    final verb = (action['action'] ?? '').toString().trim().toLowerCase();
    final tab = (tabId ?? '').trim();
    // eventSearch filters the current list; hub `search` opens catalog search.
    if (verb != 'eventsearch' && tab.isNotEmpty) {
      await openCatalogSearch(
        context,
        pluginId: pluginId,
        tabId: tab,
        hintText: hint.isEmpty ? 'Search…' : hint,
      );
      return;
    }
    if (!context.mounted) return;
    final initial = chrome?.eventQuery ?? '';
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ForjaShellColors.surfaceElevated,
        title: Text(
          (action['label'] ?? 'Search').toString(),
          style: const TextStyle(color: ForjaShellColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: ForjaShellColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint.isEmpty ? 'Search…' : hint,
            hintStyle: const TextStyle(color: ForjaShellColors.textSecondary),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    chrome?.onEventQuery(result.trim());
  }
}

/// Resolves kit.list `openSetting` (e.g. matchOpen) then mounts the list body.
class _ListOpenSettingGate extends StatefulWidget {
  const _ListOpenSettingGate({
    required this.pluginId,
    required this.openSettingId,
    required this.layoutOpen,
    required this.builder,
  });

  final String pluginId;
  final String openSettingId;
  final String layoutOpen;
  final Widget Function(String effectiveOpen) builder;

  @override
  State<_ListOpenSettingGate> createState() => _ListOpenSettingGateState();
}

class _ListOpenSettingGateState extends State<_ListOpenSettingGate> {
  String _open = kKitListOpenModeDefault;

  @override
  void initState() {
    super.initState();
    packSettingsRevisionListenable.addListener(_reload);
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant _ListOpenSettingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.openSettingId != widget.openSettingId ||
        oldWidget.layoutOpen != widget.layoutOpen) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    packSettingsRevisionListenable.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final next = await resolveListOpenMode(
      pluginId: widget.pluginId,
      openSettingId: widget.openSettingId,
      layoutOpen: widget.layoutOpen,
    );
    if (!mounted || next == _open) return;
    setState(() => _open = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_open);
}

Color? _parseMoodAccent(Object? raw) {
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty) return null;
  var hex = s;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return null;
  return Color(v);
}

/// Mood chips + optional pack load results → foundation [MoodSection].
class _MoodMount extends StatefulWidget {
  const _MoodMount({
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
  State<_MoodMount> createState() => _MoodMountState();
}

class _MoodMountState extends State<_MoodMount> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final options = widget.spec['options'];
    if (options is List && options.isNotEmpty) {
      final ids = <String>[
        for (final o in options)
          if (o is Map && o['id'] != null) o['id'].toString(),
      ];
      if (ids.isNotEmpty) {
        _selectedId = ids[DateTime.now().millisecond % ids.length];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.spec['options'];
    if (options is! List || options.isEmpty) return const SizedBox.shrink();
    final title = (widget.spec['title'] ?? '').toString();
    final pad = catalogSectionHorizontalPadding(context);
    final chips = <Widget>[];
    for (final raw in options) {
      if (raw is! Map) continue;
      final opt = Map<String, dynamic>.from(raw);
      final id = (opt['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final token = kitMoodIconToken(opt['icon']?.toString() ?? id);
      final accent = _parseMoodAccent(opt['accent']) ?? token.accent;
      final selected = _selectedId == id;
      chips.add(
        ShellMoodCircleItem(
          layout: MoodCircleLayout.desktop,
          label: (opt['label'] ?? id).toString(),
          icon: token.icon,
          accent: accent,
          selected: selected,
          onTap: () => setState(() => _selectedId = id),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    Widget? results;
    final load = packLoadSpec(widget.spec['load']);
    if (_selectedId != null && load != null) {
      results = PackLoadedPaint(
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        tabId: widget.tabId,
        action: load.action,
        params: {
          ...load.params,
          'filter': {'field': 'mood', 'value': _selectedId},
        },
        fallbackSpec: const {'type': 'rail', 'title': ''},
        builder: (ctx, merged) => PackPaintArtifact.posterRow(
          ctx,
          node: merged,
          pluginId: widget.pluginId,
        ),
      );
    }
    final layout = MoodCircleLayout.desktop;
    return MoodSection(
      title: title.isEmpty ? null : title,
      titlePadding: EdgeInsets.fromLTRB(
        pad,
        catalogSectionTitleTop(context),
        pad,
        catalogSectionBottomGap(context),
      ),
      rowHeight: layout.rowHeight,
      chipStrip: SizedBox(
        height: layout.rowHeight,
        width: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) SizedBox(width: layout.horizontalGap),
                  chips[i],
                ],
              ],
            ),
          ),
        ),
      ),
      results: results,
    );
  }
}

/// Resume seeds → pack load → foundation [BecauseSection].
class _BecauseMount extends StatefulWidget {
  const _BecauseMount({
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
  State<_BecauseMount> createState() => _BecauseMountState();
}

class _BecauseMountState extends State<_BecauseMount> {
  int _shuffleKey = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WatchHistory.revision,
      builder: (context, _, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: catalogResumeSeeds(widget.pluginId),
          builder: (context, snap) {
            final seeds = snap.data ?? const [];
            if (seeds.isEmpty) return const SizedBox.shrink();
            final load = packLoadSpec(widget.spec['load']);
            if (load == null) return const SizedBox.shrink();
            return PackLoadedPaint(
              key: ValueKey('because-$_shuffleKey'),
              pluginId: widget.pluginId,
              packSourceUrl: widget.packSourceUrl,
              tabId: widget.tabId,
              action: load.action,
              params: {
                ...load.params,
                'resumeSeeds': seeds,
                'shuffleKey': _shuffleKey,
              },
              fallbackSpec: widget.spec,
              builder: (ctx, node) {
                final items = node['items'];
                if (items is! List || items.isEmpty) {
                  return const SizedBox.shrink();
                }
                final posterItems = <PosterItem>[];
                for (final raw in items) {
                  if (raw is! Map) continue;
                  final item = Map<String, dynamic>.from(raw);
                  final props = PackPaintArtifact.propsOf(item);
                  final url = (props['imageUrl'] ?? props['posterUrl'] ?? '')
                      .toString()
                      .trim();
                  final title = (props['title'] ?? '').toString();
                  if (url.isEmpty && title.isEmpty) continue;
                  posterItems.add(
                    PosterItem(
                      url: url,
                      title: title.isEmpty ? null : title,
                      onTap: PackPaintArtifact.openTap(
                        ctx,
                        pluginId: widget.pluginId,
                        props: props,
                        open: item['open'],
                        meta: item['meta'],
                      ),
                    ),
                  );
                }
                if (posterItems.isEmpty) return const SizedBox.shrink();
                final pad = catalogSectionHorizontalPadding(ctx);
                final canShuffle = node['canShuffle'] == true;
                return BecauseSection(
                  title: (node['heading'] ?? '').toString().isEmpty
                      ? null
                      : (node['heading'] ?? '').toString(),
                  seedPosterUrl: (node['seedPoster'] ?? '').toString().isEmpty
                      ? null
                      : (node['seedPoster'] ?? '').toString(),
                  items: posterItems,
                  trailing: canShuffle
                      ? IconButton(
                          onPressed: () => setState(() => _shuffleKey++),
                          icon: const Icon(Icons.shuffle_rounded),
                          color: ForjaShellColors.iconMuted,
                        )
                      : null,
                  titlePadding: EdgeInsets.fromLTRB(
                    pad,
                    catalogSectionTitleTop(ctx),
                    pad,
                    catalogSectionBottomGap(ctx),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Host store → foundation [ContinueSection] (callbacks only).
class _ContinueMount extends StatefulWidget {
  const _ContinueMount({
    required this.pluginId,
    this.tabId,
    this.mergeHomeWatchHistory = false,
  });

  final String pluginId;
  final String? tabId;
  final bool mergeHomeWatchHistory;

  @override
  State<_ContinueMount> createState() => _ContinueMountState();
}

class _ContinueMountState extends State<_ContinueMount> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;

  @override
  void initState() {
    super.initState();
    WatchHistory.revision.addListener(_reload);
    if (widget.mergeHomeWatchHistory) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_reload());
      });
    }
    unawaited(_reload());
  }

  @override
  void dispose() {
    WatchHistory.revision.removeListener(_reload);
    unawaited(_homeHistorySub?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await catalogContinueEntries(
        widget.pluginId,
        mergeHomeWatchHistory: widget.mergeHomeWatchHistory,
      );
      if (!mounted) return;
      setState(() => _entries = list);
    } catch (_) {}
  }

  Map<String, dynamic>? _byId(String metaId) {
    for (final e in _entries) {
      if (e['metaId']?.toString() == metaId) return e;
    }
    return null;
  }

  Future<void> _resume(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final home = entry['homeHistory'];
      if (home is! Map || _resumingMetaId != null) return;
      final metaId = entry['metaId']?.toString();
      if (metaId == null) return;
      setState(() => _resumingMetaId = metaId);
      try {
        await resumePlaybackFromHistory(
          context,
          Map<String, dynamic>.from(home),
        );
        if (mounted) await _reload();
      } catch (e) {
        if (mounted) ForjaToast.error('Resume failed: $e');
      } finally {
        if (mounted) setState(() => _resumingMetaId = null);
      }
      return;
    }
    final metaId = entry['metaId']?.toString();
    if (metaId == null || _resumingMetaId != null) return;
    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    setState(() => _resumingMetaId = metaId);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      if (posMs > 5000 && canResumeFromSavedProgress(posMs, durMs)) {
        final clamped = (durMs > 0 && posMs > durMs - 30000)
            ? (durMs - 30000)
            : posMs;
        startPosition =
            Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
      }
      final extras = entry['extras'];
      final ctx = catalogPlayContextFromMeta(
        meta: meta,
        pluginId: widget.pluginId,
        episodeNumber: epNum,
        episodeVideoId: entry['episodeVideoId']?.toString(),
        extras: extras is Map
            ? Map<String, dynamic>.from(extras)
            : const {},
        startPosition: startPosition,
      );
      if (!mounted) return;
      await runPlayFromContext(context: context, ctx: ctx);
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _resumingMetaId = null);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final metaJson = entry['meta'];
      if (metaJson is! Map) return;
      final meta = MetaItem.fromJson(Map<String, dynamic>.from(metaJson));
      final home = entry['homeHistory'];
      await openMetaItem(
        context,
        pluginId: widget.pluginId,
        item: meta,
        initialSeason: home is Map ? home['season'] as int? : null,
        initialEpisode: home is Map ? home['episode'] as int? : null,
      );
      if (mounted) await _reload();
      return;
    }
    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    await openMetaItem(context, pluginId: widget.pluginId, item: meta);
    if (mounted) await _reload();
  }

  Future<void> _remove(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final id = entry['metaId']?.toString();
      if (id == null) return;
      await WatchHistoryService().removeItem(id);
      if (mounted) await _reload();
      return;
    }
    final id = entry['metaId']?.toString();
    if (id == null) return;
    await WatchHistory.remove(widget.pluginId, id);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();
    final showArrows = ShellScope.inputPolicyOf(context).scaleOnHover;
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final cardW = tv
        ? 140.0
        : (shellUsesWideLayout(context)
            ? ShellTokens.shellContinueWatchingCardWidthDesktop
            : ShellTokens.shellContinueWatchingCardWidthCompact);
    final pad = catalogSectionHorizontalPadding(context);
    final tab = (widget.tabId ?? TvFocusGraph.tabIdOf(context)).trim();
    return TvKitRow(
      tabId: tab,
      rowId: 'continue_watching',
      sortOrder: 20,
      itemCount: _entries.length,
      onFocusUp: LayoutScope.maybeOf(context)?.resolveFocusEdge('spotlight'),
      child: ContinueSection(
        scrollController: _scroll,
        showScrollArrows: showArrows,
        cardWidth: cardW,
        cardHeight: cardW * 9 / 16,
        titlePadding: EdgeInsets.fromLTRB(
          pad,
          shellSectionTitleTopCompact(context),
          pad,
          16,
        ),
        listPadding: EdgeInsets.symmetric(horizontal: pad),
        entries: [for (final e in _entries) ContinueEntry.fromMap(e)],
        resumingMetaId: _resumingMetaId,
        onResume: (entry) {
          final raw = _byId(entry.metaId);
          if (raw != null) unawaited(_resume(raw));
        },
        onInfo: (entry) {
          final raw = _byId(entry.metaId);
          if (raw != null) unawaited(_openDetails(raw));
        },
        onRemove: (entry) {
          final raw = _byId(entry.metaId);
          if (raw != null) unawaited(_remove(raw));
        },
      ),
    );
  }
}
