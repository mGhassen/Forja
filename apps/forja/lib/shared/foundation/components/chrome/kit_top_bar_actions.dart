import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/components/layout/kit_focus.dart';
import 'package:forja/shared/foundation/components/layout/kit_layout_scope.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Enabled live catalog plugins for the Catalog filter sheet.
final liveCatalogFilterOptionsProvider =
    FutureProvider.autoDispose<List<({String id, String label})>>((ref) async {
  final plugins = await EngineService.instance.listEnabledLiveFeedPlugins();
  return [
    for (final p in plugins)
      (
        id: EngineService.normalizeLiveSportPluginId(p.id),
        label: p.name.trim().isEmpty ? p.id : p.name.trim(),
      ),
  ];
});

/// Layout widget [`kit.topBar`] — IPTV-style Catalog / Schedule / Refresh chrome.
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
    final catalogsAsync = ref.watch(liveCatalogFilterOptionsProvider);

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
  }) {
    final verb = (action['action'] ?? '').toString().trim().toLowerCase();
    final id = (action['id'] ?? '').toString();
    final isRefresh = verb == 'refresh' || id == 'refresh';
    final icon = _iconFor(action);

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
      label: _chipLabel(scope, action, catalogOptions: catalogOptions),
      icon: icon,
      selected: _isSelected(scope, action),
      tvTabId: tabId,
      tvRowId: _widgetId,
      tvItemIndex: index,
      onLeftEdge: index == 0 ? null : () {},
      onRightEdge: index == _actions.length - 1 ? null : () {},
      onDownEdge: focusDown ?? () {},
      onTap: () => unawaited(
        _onAction(context, scope, action, catalogOptions: catalogOptions),
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
        // Keep pack-declared extras that are not already in enabled list.
        for (final s in staticItems)
          if (s.id != 'all' && !catalogOptions.any((c) => c.id == s.id))
            (id: s.id, label: s.label, subtitle: null),
      ];
    }
    return [
      for (final s in staticItems) (id: s.id, label: s.label, subtitle: null),
    ];
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
    final hint = id == 'catalog'
        ? 'Filter the schedule by catalog:'
        : id == 'horizon'
            ? 'Show matches in this time window:'
            : null;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ForjaShellColors.surfaceElevated,
      isScrollControlled: true,
      builder: (ctx) {
        final selected = scope.selectedId(id) ?? 'all';
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
                    if (hint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final item in items)
                      _SheetOption(
                        label: item.label,
                        subtitle: item.subtitle,
                        selected: item.id == selected ||
                            (selected.isEmpty && item.id == 'all'),
                        onTap: () => Navigator.pop(ctx, item.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect(id, picked, toggle: false);
  }
}

class _SheetOption extends StatefulWidget {
  const _SheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SheetOption> createState() => _SheetOptionState();
}

class _SheetOptionState extends State<_SheetOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovered = h),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.selected
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
                    : ForjaShellColors.borderSubtle.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.selected
                              ? ForjaShellColors.brandGreen
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!.trim(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.selected)
                  const Icon(
                    Icons.check_rounded,
                    color: ForjaShellColors.brandGreen,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
