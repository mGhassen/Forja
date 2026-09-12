import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/shell/kit_filter_sheet_option.dart';
import 'package:forja/shared/engine/hub/kit_feed_chrome.dart';
import 'package:forja/shared/shell/focus_edge.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja/shared/shell/kit_list_event_search.dart';
import 'package:forja/shared/shell/forja_action_chip.dart';
import 'package:forja/shared/engine/hub/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';

export 'package:forja_foundation/widgets/chrome/top_bar_actions.dart'
    show TopBarActions;

/// Opaque pack `deps` on catalog actions (`deps: ['stremio']`, …).
///
/// Host maps known tokens to revision watches — unknown tokens are ignored.
List<String> kitTopBarCatalogDeps(List<Map<String, dynamic>> actions) {
  final out = <String>{};
  for (final a in actions) {
    final id = (a['id'] ?? '').toString();
    final isCatalog = id == 'catalog' || a['dynamicCatalogs'] == true;
    if (!isCatalog) continue;
    final raw = a['deps'];
    if (raw is! List) continue;
    for (final d in raw) {
      final s = d?.toString().trim().toLowerCase() ?? '';
      if (s.isNotEmpty) out.add(s);
    }
  }
  final list = out.toList()..sort();
  return list;
}

String kitTopBarCatalogDepsKey(List<String> deps) => deps.join(',');

/// Dynamic catalog options from [KitTopBarHostHooks.loadCatalogOptions].
///
/// [depsKey] is sorted pack `deps` joined by `,` (empty = no revision watches).
final kitTopBarCatalogOptionsProvider = FutureProvider.autoDispose
    .family<List<({String id, String label})>, String>((ref, depsKey) async {
  for (final d in depsKey.split(',')) {
    final token = d.trim();
    if (token.isEmpty) continue;
    switch (token) {
      case 'stremio':
        ref.watch(addonRevisionProvider);
      default:
        break;
    }
  }
  final loader = KitTopBarHostHooks.loadCatalogOptions;
  if (loader == null) return const [];
  return loader();
});

/// Layout widget [`kit.topBar`] — pack-declared actions only.
///
/// Leading chips (Catalog / Schedule / Refresh) sit left of [Spacer].
/// Actions with `trailing: true` sit right. Host never invents chrome;
/// opaque verbs use [KitTopBarHostHooks.packActionBuilders] (e.g. portals).
class KitTopBarActions extends ConsumerWidget {
  const KitTopBarActions({
    super.key,
    required this.tabId,
    required this.spec,
    this.sortOrder = 0,
    this.onRefresh,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final int sortOrder;
  final VoidCallback? onRefresh;

  String get _widgetId => (spec['id'] ?? 'topBar').toString();

  List<Map<String, dynamic>> get _actions {
    final raw = spec['actions'];
    if (raw is! List) return const [];
    return [
      for (final a in raw)
        if (a is Map) Map<String, dynamic>.from(a),
    ];
  }

  static bool _isTrailing(Map<String, dynamic> action) {
    if (action['trailing'] == true) return true;
    final slot = (action['slot'] ?? '').toString().trim().toLowerCase();
    return slot == 'trailing' || slot == 'end' || slot == 'right';
  }

  static String _verb(Map<String, dynamic> action) {
    final a = (action['action'] ?? '').toString().trim().toLowerCase();
    if (a.isNotEmpty) return a;
    return (action['id'] ?? '').toString().trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actions;
    if (actions.isEmpty) return const SizedBox.shrink();
    final scope = LayoutScope.of(context);
    // last: restore prior schedule/list index (↑ from match → Portals → ↓).
    final focusDown =
        kitFocusEdge(tabId, spec['focusDown']?.toString(), last: true);
    final focusLeft = kitFocusSide(tabId, spec['focusLeft']);
    final focusRight = kitFocusSide(tabId, spec['focusRight']);
    final depsKey = kitTopBarCatalogDepsKey(kitTopBarCatalogDeps(actions));
    final catalogsAsync = ref.watch(kitTopBarCatalogOptionsProvider(depsKey));
    final catalogOptions = catalogsAsync.asData?.value ?? const [];
    final chromeKey = kitChromeKeyForTab(tabId);
    final layoutHorizon = scope.selectedId('horizon') ??
        scope.selectedId('schedule') ??
        scope.selectedId('time');
    final horizonPref = chromeKey.isEmpty
        ? ''
        : ref.watch(kitFeedHorizonPrefProvider(chromeKey));
    final resolvedHorizon =
        (layoutHorizon == null || layoutHorizon.isEmpty)
            ? horizonPref
            : layoutHorizon;
    final layoutCatalog = scope.selectedId('catalog');
    final catalogPref =
        KitTopBarHostHooks.readCatalogPref?.call(ref, tabId: tabId) ??
            layoutCatalog;
    final feedBusy =
        KitTopBarHostHooks.readFeedBusy?.call(ref, tabId: tabId);
    final busy = feedBusy?.busy == true;
    final busyLabel = () {
      final raw = (feedBusy?.label ?? '').trim();
      if (raw.isNotEmpty) return raw;
      return 'Loading…';
    }();
    final updatedLabel = busy
        ? ''
        : (KitTopBarHostHooks.readFeedUpdatedLabel?.call(ref, tabId: tabId) ??
                '')
            .trim();

    final leading = <Map<String, dynamic>>[];
    final trailing = <Map<String, dynamic>>[];
    for (final a in actions) {
      if (_isTrailing(a)) {
        trailing.add(a);
      } else {
        leading.add(a);
      }
    }

    var planned = 0;
    for (final a in leading) {
      if (busy && _isRefreshAction(a)) continue;
      planned++;
    }
    for (final a in trailing) {
      if (busy && _isRefreshAction(a)) continue;
      planned++;
    }
    final lastIndex = planned - 1;

    final built = <Widget>[];
    var index = 0;
    for (final a in leading) {
      // Hide Refresh while scrape/search is busy — status text sits center-top.
      if (busy && _isRefreshAction(a)) continue;
      final w = _buildAction(
        context,
        ref,
        scope,
        a,
        index: index,
        focusDown: focusDown,
        focusLeft: index == 0 ? focusLeft : null,
        focusRight: index == lastIndex ? focusRight : null,
        catalogOptions: catalogOptions,
        catalogPref: catalogPref,
        horizonPref: resolvedHorizon,
      );
      if (w != null) {
        built.add(w);
        index++;
      }
    }
    final leadingCount = built.length;
    final trailingBuilt = <Widget>[];
    for (final a in trailing) {
      if (busy && _isRefreshAction(a)) continue;
      final w = _buildAction(
        context,
        ref,
        scope,
        a,
        index: index,
        focusDown: focusDown,
        focusLeft: index == 0 ? focusLeft : null,
        focusRight: index == lastIndex ? focusRight : null,
        catalogOptions: catalogOptions,
        catalogPref: catalogPref,
        horizonPref: resolvedHorizon,
      );
      if (w != null) {
        trailingBuilt.add(w);
        index++;
      }
    }

    final Widget? centerStatus;
    if (busy) {
      centerStatus = _KitTopBarCatalogProgressChip(label: busyLabel);
    } else if (updatedLabel.isNotEmpty) {
      centerStatus = _KitTopBarUpdatedLabel(label: updatedLabel);
    } else {
      centerStatus = null;
    }

    final itemCount = leadingCount + trailingBuilt.length;
    final chromeOrder = sortOrder < 0 ? sortOrder : -100 - sortOrder;
    return TopBarActions(
      leading: built,
      trailing: trailingBuilt,
      center: centerStatus,
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        ShellTokens.tabHeaderTopPadding,
        ShellTokens.bodyHorizontalPadding,
        4,
      ),
      wrapRow: (child) => TvKitRow(
        tabId: tabId,
        rowId: _widgetId,
        sortOrder: chromeOrder,
        itemCount: itemCount,
        onFocusUp: () {},
        child: child,
      ),
    );
  }

  static bool _isRefreshAction(Map<String, dynamic> action) {
    final verb = _verb(action);
    final id = (action['id'] ?? '').toString();
    return verb == 'refresh' || id == 'refresh';
  }

  Widget? _buildAction(
    BuildContext context,
    WidgetRef ref,
    LayoutScope scope,
    Map<String, dynamic> action, {
    required int index,
    required VoidCallback? focusDown,
    required VoidCallback? focusLeft,
    required VoidCallback? focusRight,
    required List<({String id, String label})> catalogOptions,
    required String? catalogPref,
    required String? horizonPref,
  }) {
    final verb = _verb(action);
    final id = (action['id'] ?? '').toString();
    final isRefresh = verb == 'refresh' || id == 'refresh';
    final isView = id == 'view' || verb == 'view' || verb == 'scheduleview';
    final isSchedule = id == 'horizon' || id == 'schedule' || id == 'time';
    final isCatalog = id == 'catalog' || action['dynamicCatalogs'] == true;

    if (verb == 'eventsearch' || verb == 'search') {
      final tooltip = (action['label'] ?? 'Search').toString().trim();
      final hint = (action['placeholder'] ?? action['hint'] ?? '').toString().trim();
      return KitListEventSearch(
        tabId: tabId,
        rowId: _widgetId,
        itemIndex: index,
        tooltip: tooltip.isEmpty ? 'Search' : tooltip,
        placeholder: hint.isEmpty ? 'Search…' : hint,
        onDownEdge: focusDown,
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
      );
    }

    final hostBuilder = KitTopBarHostHooks.packActionBuilders[verb] ??
        KitTopBarHostHooks.packActionBuilders[id];
    if (hostBuilder != null) {
      return hostBuilder(
        context,
        ref,
        action: action,
        tabId: tabId,
        rowId: _widgetId,
        itemIndex: index,
        onDownEdge: focusDown,
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
      );
    }

    final icon = _iconFor(action);
    final catalogLabel = KitTopBarHostHooks.catalogChipLabel;
    final catalogSelected = KitTopBarHostHooks.catalogChipSelected;

    if (isRefresh) {
      return ForjaActionChip(
        label: 'Refresh',
        icon: icon ?? Icons.refresh_rounded,
        iconOnly: true,
        selected: false,
        tvTabId: tabId,
        tvRowId: _widgetId,
        tvItemIndex: index,
        onDownEdge: focusDown ?? () {},
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
        onTap: () => onRefresh?.call(),
      );
    }

    if (isView) {
      final key = kitChromeKeyForTab(tabId);
      final override = key.isEmpty
          ? ''
          : ref.watch(kitListStyleOverrideProvider(key)).trim().toLowerCase();
      final isCards = override == 'cards';
      return ForjaActionChip(
        label: isCards ? 'Cards view' : 'List view',
        icon: isCards ? Icons.grid_view_rounded : Icons.view_list_rounded,
        iconOnly: true,
        selected: false,
        tvTabId: tabId,
        tvRowId: _widgetId,
        tvItemIndex: index,
        onDownEdge: focusDown ?? () {},
        onLeftEdge: focusLeft,
        onRightEdge: focusRight,
        onTap: () {
          if (key.isEmpty) return;
          ref.read(kitListStyleOverrideProvider(key).notifier).state =
              isCards ? 'list' : 'cards';
        },
      );
    }

    final String label;
    final bool selected;
    if (isSchedule) {
      final hookLabel = KitTopBarHostHooks.scheduleChipLabel;
      label = hookLabel != null
          ? hookLabel(horizonPref)
          : _horizonChipLabel(action, horizonPref, catalogOptions);
      final hookSelected = KitTopBarHostHooks.scheduleChipSelected;
      selected = hookSelected != null
          ? hookSelected(horizonPref)
          : (horizonPref != null &&
              horizonPref.isNotEmpty &&
              horizonPref != _packActionDefault(action));
    } else if (isCatalog && catalogLabel != null) {
      label = catalogLabel(catalogPref, catalogOptions);
      selected = catalogSelected?.call(catalogPref) ?? false;
    } else {
      label = _chipLabel(scope, action, catalogOptions: catalogOptions);
      selected = _isSelected(scope, action);
    }

    return ForjaActionChip(
      label: label,
      icon: icon,
      selected: selected,
      tvTabId: tabId,
      tvRowId: _widgetId,
      tvItemIndex: index,
      onDownEdge: focusDown ?? () {},
      onLeftEdge: focusLeft,
      onRightEdge: focusRight,
      onTap: () => unawaited(
        isSchedule
            ? _onSchedule(
                context,
                ref,
                scope,
                action: action,
                horizonPref: horizonPref,
                catalogOptions: catalogOptions,
              )
            : isCatalog
                ? _onCatalog(
                    context,
                    scope,
                    catalogOptions: catalogOptions,
                    catalogPref: catalogPref,
                  )
                : _onAction(
                    context,
                    ref,
                    scope,
                    action,
                    catalogOptions: catalogOptions,
                  ),
      ),
    );
  }

  String _horizonChipLabel(
    Map<String, dynamic> action,
    String? horizonPref,
    List<({String id, String label})> catalogOptions,
  ) {
    final items = _itemsFor(action, catalogOptions: catalogOptions);
    final pref = (horizonPref ?? '').trim().isNotEmpty
        ? horizonPref!.trim()
        : _packActionDefault(action);
    for (final item in items) {
      if (item.id == pref) return item.label;
    }
    return (action['label'] ?? 'Schedule').toString();
  }

  static String _packActionDefault(Map<String, dynamic> action) =>
      (action['default'] ?? '').toString().trim();

  String _chipLabel(
    LayoutScope scope,
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) {
    final id = (action['id'] ?? '').toString();
    final base = (action['label'] ?? id).toString();
    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return base;
    final selected = scope.selectedId(id);
    if (selected == null || selected.isEmpty || selected == 'all') return base;
    for (final item in items) {
      if (item.id == selected) return '$base: ${item.label}';
    }
    return base;
  }

  bool _isSelected(LayoutScope scope, Map<String, dynamic> action) {
    final id = (action['id'] ?? '').toString();
    final selected = scope.selectedId(id);
    if (selected == null || selected.isEmpty || selected == 'all') return false;
    return true;
  }

  IconData? _iconFor(Map<String, dynamic> action) {
    final name = (action['icon'] ?? '').toString().trim().toLowerCase();
    return switch (name) {
      'refresh' => Icons.refresh_rounded,
      'search' => Icons.search,
      'filter' || 'catalog' => Icons.filter_list,
      'schedule' || 'time' || 'horizon' => Icons.schedule,
      'view' || 'list' => Icons.view_list_rounded,
      'cards' || 'grid' => Icons.grid_view_rounded,
      _ => null,
    };
  }

  List<({String id, String label, String? subtitle})> _itemsFor(
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) {
    final id = (action['id'] ?? '').toString();
    final staticItems = layoutItemsFromSpec(action);
    if (id == 'catalog' || action['dynamicCatalogs'] == true) {
      return [
        (id: 'all', label: 'All', subtitle: 'Every enabled catalog'),
        for (final c in catalogOptions)
          (id: c.id, label: c.label, subtitle: null),
        for (final s in staticItems)
          if (s.id != 'all' && !catalogOptions.any((c) => c.id == s.id))
            (id: s.id, label: s.label, subtitle: null),
      ];
    }
    return [
      for (final s in staticItems) (id: s.id, label: s.label, subtitle: null),
    ];
  }

  Future<void> _onCatalog(
    BuildContext context,
    LayoutScope scope, {
    required List<({String id, String label})> catalogOptions,
    required String? catalogPref,
  }) async {
    final items = _itemsFor(
      const {'id': 'catalog', 'dynamicCatalogs': true},
      catalogOptions: catalogOptions,
    );
    if (items.isEmpty) return;
    final current = (catalogPref ?? scope.selectedId('catalog') ?? 'all').trim();
    final opener = KitTopBarHostHooks.openCatalogSheet;
    final picked = opener != null
        ? await opener(
            context,
            current: current.isEmpty ? 'all' : current,
            options: items,
          )
        : await _genericPicker(
            context,
            title: 'Catalog',
            sheetId: 'catalog',
            current: current.isEmpty ? 'all' : current,
            items: items,
          );
    if (picked == null || !context.mounted) return;
    scope.onSelect('catalog', picked, toggle: false);
    final writer = KitTopBarHostHooks.writeCatalogFilter;
    if (writer != null) {
      await writer(context, picked, tabId: tabId);
    }
  }

  Future<void> _onSchedule(
    BuildContext context,
    WidgetRef ref,
    LayoutScope scope, {
    required Map<String, dynamic> action,
    required String? horizonPref,
    required List<({String id, String label})> catalogOptions,
  }) async {
    final current = ((horizonPref ?? '').trim().isNotEmpty
            ? horizonPref!.trim()
            : _packActionDefault(action))
        .trim();
    final opener = KitTopBarHostHooks.openScheduleSheet;
    if (opener != null) {
      await opener(
        context,
        currentPref:
            current.isEmpty ? 'airing|1h' : current,
        onChanged: (pref) {
          if (!context.mounted) return;
          scope.onSelect('horizon', pref, toggle: false);
          final key = kitChromeKeyForTab(tabId);
          if (key.isNotEmpty) {
            ref.read(kitFeedHorizonPrefProvider(key).notifier).state = pref;
          }
        },
      );
      return;
    }

    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return;
    final picked = await _genericPicker(
      context,
      title: (action['label'] ?? 'Schedule').toString(),
      sheetId: 'horizon',
      current: current.isEmpty ? 'airing|1h' : current,
      items: items,
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect('horizon', picked, toggle: false);
    final key = kitChromeKeyForTab(tabId);
    if (key.isNotEmpty) {
      ref.read(kitFeedHorizonPrefProvider(key).notifier).state = picked;
    }
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    LayoutScope scope,
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) async {
    final id = (action['id'] ?? '').toString();
    final verb = (action['action'] ?? '').toString().trim().toLowerCase();
    if (verb == 'refresh') {
      onRefresh?.call();
      return;
    }
    if (verb == 'search') return;

    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return;

    final title = (action['label'] ?? id).toString();
    final picked = await _genericPicker(
      context,
      title: title,
      sheetId: id,
      current: scope.selectedId(id) ?? 'all',
      items: items,
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect(id, picked, toggle: false);
    if (id == 'view' || verb == 'view') {
      final key = kitChromeKeyForTab(tabId);
      if (key.isNotEmpty) {
        ref.read(kitListStyleOverrideProvider(key).notifier).state = picked;
      }
    }
  }

  Future<String?> _genericPicker(
    BuildContext context, {
    required String title,
    required String sheetId,
    required String current,
    required List<({String id, String label, String? subtitle})> items,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ForjaShellColors.surfaceElevated,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.7;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < items.length; i++)
                      KitFilterSheetOption(
                        label: items[i].label,
                        subtitle: items[i].subtitle,
                        selected: items[i].id == current ||
                            (current.isEmpty && items[i].id == 'all'),
                        icon: items[i].id == 'all'
                            ? Icons.grid_view_rounded
                            : Icons.tune_rounded,
                        onSelected: () => Navigator.pop(ctx, items[i].id),
                        tvTabId: 'kit_top_bar_sheet_$sheetId',
                        tvRowId: 'kit-sheet-$sheetId',
                        tvItemIndex: i,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Center-top scrape progress — spinner left, label right.
class _KitTopBarCatalogProgressChip extends StatelessWidget {
  const _KitTopBarCatalogProgressChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final maxW = (MediaQuery.sizeOf(context).width * 0.42).clamp(160.0, 360.0);
    return ExcludeFocus(
      child: Tooltip(
        message: label,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ForjaShellColors.borderSubtle.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: ForjaShellColors.sectionAccent,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Center-top idle status — e.g. `Updated just now` (Refresh icon stays leading).
class _KitTopBarUpdatedLabel extends StatelessWidget {
  const _KitTopBarUpdatedLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ForjaShellColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
