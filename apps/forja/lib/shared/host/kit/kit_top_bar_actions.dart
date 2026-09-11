import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/host/kit/kit_filter_sheet_option.dart';
import 'package:forja/shared/host/kit/kit_feed_chrome.dart';
import 'package:forja/shared/host/kit/kit_focus.dart';
import 'package:forja/shared/host/kit/kit_layout_scope.dart';
import 'package:forja/shared/host/kit/kit_schedule_event_search.dart';
import 'package:forja/shared/shell/forja_action_chip.dart';
import 'package:forja/shared/host/kit/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Dynamic catalog options from [KitTopBarHostHooks.loadCatalogOptions].
final kitTopBarCatalogOptionsProvider =
    FutureProvider.autoDispose<List<({String id, String label})>>((ref) async {
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
    final scope = KitLayoutScope.of(context);
    // last: restore prior schedule/list index (↑ from match → Portals → ↓).
    final focusDown =
        kitFocusEdge(tabId, spec['focusDown']?.toString(), last: true);
    final focusLeft = kitFocusSide(tabId, spec['focusLeft']);
    final focusRight = kitFocusSide(tabId, spec['focusRight']);
    final catalogsAsync = ref.watch(kitTopBarCatalogOptionsProvider);
    final catalogOptions = catalogsAsync.asData?.value ?? const [];
    final layoutHorizon = scope.selectedId('horizon') ??
        scope.selectedId('schedule') ??
        scope.selectedId('time');
    final horizonPref = ref.watch(kitFeedHorizonPrefProvider);
    final resolvedHorizon =
        (layoutHorizon == null || layoutHorizon.isEmpty)
            ? horizonPref
            : layoutHorizon;
    final layoutCatalog = scope.selectedId('catalog');
    final catalogPref =
        KitTopBarHostHooks.readCatalogPref?.call(ref) ?? layoutCatalog;
    final feedBusy = KitTopBarHostHooks.readFeedBusy?.call(ref);
    final busy = feedBusy?.busy == true;
    final busyLabel = () {
      final raw = (feedBusy?.label ?? '').trim();
      if (raw.isNotEmpty) return raw;
      return 'Loading live catalogs…';
    }();

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
    if (busy) planned++;
    for (final a in trailing) {
      if (busy && _isRefreshAction(a)) continue;
      planned++;
    }
    final lastIndex = planned - 1;

    final built = <Widget>[];
    var index = 0;
    for (final a in leading) {
      // Hide Refresh while scrape/search is busy — progress chip goes trailing.
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
    if (busy) {
      trailingBuilt.add(_KitTopBarCatalogProgressChip(label: busyLabel));
      index++;
    }
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

    final itemCount = leadingCount + trailingBuilt.length;
    final chromeOrder = sortOrder < 0 ? sortOrder : -100 - sortOrder;
    return TvKitRow(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: chromeOrder,
      itemCount: itemCount,
      onFocusUp: () {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellTokens.compactChromeLeadingInset(context),
          ShellTokens.tabHeaderTopPadding,
          ShellTokens.bodyHorizontalPadding,
          4,
        ),
        child: Row(
          children: [
            for (var i = 0; i < built.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              built[i],
            ],
            const Spacer(),
            for (var t = 0; t < trailingBuilt.length; t++) ...[
              const SizedBox(width: 8),
              trailingBuilt[t],
            ],
          ],
        ),
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
    KitLayoutScope scope,
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
    final isSchedule = id == 'horizon' || id == 'schedule' || id == 'time';
    final isCatalog = id == 'catalog' || action['dynamicCatalogs'] == true;

    if (verb == 'eventsearch' || verb == 'search') {
      return KitScheduleEventSearch(
        tabId: tabId,
        rowId: _widgetId,
        itemIndex: index,
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
      final updated =
          (KitTopBarHostHooks.readFeedUpdatedLabel?.call(ref) ?? '').trim();
      final chip = ForjaActionChip(
        label: updated.isEmpty ? '' : updated,
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
      if (updated.isEmpty) return chip;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeFocus(
            child: Text(
              updated,
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          chip,
        ],
      );
    }

    final String label;
    final bool selected;
    if (isSchedule) {
      label = _horizonChipLabel(action, horizonPref, catalogOptions);
      selected = horizonPref != null &&
          horizonPref.isNotEmpty &&
          horizonPref != 'airing|1h';
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
    final pref = (horizonPref ?? 'airing|1h').trim();
    for (final item in items) {
      if (item.id == pref) return item.label;
    }
    return (action['label'] ?? 'Schedule').toString();
  }

  String _chipLabel(
    KitLayoutScope scope,
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

  bool _isSelected(KitLayoutScope scope, Map<String, dynamic> action) {
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
      _ => null,
    };
  }

  List<({String id, String label, String? subtitle})> _itemsFor(
    Map<String, dynamic> action, {
    required List<({String id, String label})> catalogOptions,
  }) {
    final id = (action['id'] ?? '').toString();
    final staticItems = kitItemsFromSpec(action);
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
    KitLayoutScope scope, {
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
      await writer(context, picked);
    }
  }

  Future<void> _onSchedule(
    BuildContext context,
    WidgetRef ref,
    KitLayoutScope scope, {
    required Map<String, dynamic> action,
    required String? horizonPref,
    required List<({String id, String label})> catalogOptions,
  }) async {
    final items = _itemsFor(action, catalogOptions: catalogOptions);
    if (items.isEmpty) return;
    final picked = await _genericPicker(
      context,
      title: (action['label'] ?? 'Schedule').toString(),
      sheetId: 'horizon',
      current: (horizonPref ?? 'airing|1h').trim(),
      items: items,
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect('horizon', picked, toggle: false);
    ref.read(kitFeedHorizonPrefProvider.notifier).state = picked;
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    KitLayoutScope scope,
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
      ref.read(kitListStyleOverrideProvider.notifier).state = picked;
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

/// Replaces top-bar Refresh while live catalogs scrape / merge.
class _KitTopBarCatalogProgressChip extends StatelessWidget {
  const _KitTopBarCatalogProgressChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Tooltip(
        message: label,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
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
