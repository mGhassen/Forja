import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/components/chrome/kit_filter_sheet_option.dart';
import 'package:forja/shared/foundation/components/layout/kit_focus.dart';
import 'package:forja/shared/foundation/components/layout/kit_layout_scope.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/registry/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';

/// Dynamic catalog options from [KitTopBarHostHooks.loadCatalogOptions].
final kitTopBarCatalogOptionsProvider =
    FutureProvider.autoDispose<List<({String id, String label})>>((ref) async {
  final loader = KitTopBarHostHooks.loadCatalogOptions;
  if (loader == null) return const [];
  return loader();
});

/// Layout widget [`kit.topBar`] — Catalog / Schedule / Refresh chrome.
///
/// Product sheets (Live Sports catalog/schedule) register via
/// [KitTopBarHostHooks] — this widget stays pack-agnostic.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actions;
    if (actions.isEmpty) return const SizedBox.shrink();
    final scope = KitLayoutScope.of(context);
    final focusDown = kitFocusEdge(tabId, spec['focusDown']?.toString());
    final catalogsAsync = ref.watch(kitTopBarCatalogOptionsProvider);
    final horizonPref = scope.selectedId('horizon') ??
        scope.selectedId('schedule') ??
        scope.selectedId('time');

    return TvKitRow(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: sortOrder,
      itemCount: actions.length,
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
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _buildAction(
                context,
                scope,
                actions[i],
                index: i,
                focusDown: focusDown,
                catalogOptions: catalogsAsync.asData?.value ?? const [],
                horizonPref: horizonPref,
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    KitLayoutScope scope,
    Map<String, dynamic> action, {
    required int index,
    required VoidCallback? focusDown,
    required List<({String id, String label})> catalogOptions,
    required String? horizonPref,
  }) {
    final verb = (action['action'] ?? '').toString().trim().toLowerCase();
    final id = (action['id'] ?? '').toString();
    final isRefresh = verb == 'refresh' || id == 'refresh';
    final isSchedule = id == 'horizon' || id == 'schedule' || id == 'time';
    final icon = _iconFor(action);
    final scheduleLabel = KitTopBarHostHooks.scheduleChipLabel;
    final scheduleSelected = KitTopBarHostHooks.scheduleChipSelected;

    if (isRefresh) {
      return ForjaActionChip(
        label: '',
        icon: icon ?? Icons.refresh_rounded,
        iconOnly: true,
        selected: false,
        tvTabId: tabId,
        tvRowId: _widgetId,
        tvItemIndex: index,
        onDownEdge: focusDown ?? () {},
        onTap: () => onRefresh?.call(),
      );
    }

    return ForjaActionChip(
      label: isSchedule && scheduleLabel != null
          ? scheduleLabel(horizonPref)
          : _chipLabel(scope, action, catalogOptions: catalogOptions),
      icon: icon,
      selected: isSchedule && scheduleSelected != null
          ? scheduleSelected(horizonPref)
          : _isSelected(scope, action),
      tvTabId: tabId,
      tvRowId: _widgetId,
      tvItemIndex: index,
      onLeftEdge: index == 0 ? null : () {},
      onRightEdge: index == _actions.length - 1 ? null : () {},
      onDownEdge: focusDown ?? () {},
      onTap: () => unawaited(
        isSchedule
            ? _onSchedule(context, scope, horizonPref: horizonPref)
            : id == 'catalog'
                ? _onCatalog(context, scope, catalogOptions: catalogOptions)
                : _onAction(
                    context,
                    scope,
                    action,
                    catalogOptions: catalogOptions,
                  ),
      ),
    );
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
  }) async {
    final items = _itemsFor(
      const {'id': 'catalog', 'dynamicCatalogs': true},
      catalogOptions: catalogOptions,
    );
    if (items.isEmpty) return;
    final opener = KitTopBarHostHooks.openCatalogSheet;
    final picked = opener != null
        ? await opener(
            context,
            current: scope.selectedId('catalog') ?? 'all',
            options: items,
          )
        : await _genericPicker(
            context,
            title: 'Catalog',
            sheetId: 'catalog',
            current: scope.selectedId('catalog') ?? 'all',
            items: items,
          );
    if (picked == null || !context.mounted) return;
    scope.onSelect('catalog', picked, toggle: false);
  }

  Future<void> _onSchedule(
    BuildContext context,
    KitLayoutScope scope, {
    required String? horizonPref,
  }) async {
    final opener = KitTopBarHostHooks.openScheduleSheet;
    if (opener == null) return;
    await opener(
      context,
      currentPref: horizonPref ?? 'both|24h',
      onChanged: (pref) {
        if (!context.mounted) return;
        scope.onSelect('horizon', pref, toggle: false);
      },
    );
  }

  Future<void> _onAction(
    BuildContext context,
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
