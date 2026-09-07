import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_kit_action_chip.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_focus.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Layout widget [`kit.topBar`] — pack-composed action chips (filter badges, etc.).
///
/// Spec:
/// ```json
/// {
///   "type": "kit.topBar",
///   "id": "chrome",
///   "actions": [
///     { "id": "catalog", "label": "Catalog", "style": "badge", "items": [...] },
///     { "id": "horizon", "label": "Schedule", "style": "badge", "items": [...] },
///     { "id": "refresh", "label": "Refresh", "icon": "refresh", "action": "refresh" }
///   ]
/// }
/// ```
class CatalogKitTopBarActions extends StatelessWidget {
  const CatalogKitTopBarActions({
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
  Widget build(BuildContext context) {
    final actions = _actions;
    if (actions.isEmpty) return const SizedBox.shrink();
    final scope = CatalogLayoutScope.of(context);
    final focusDown = catalogKitFocusEdge(tabId, spec['focusDown']?.toString());

    return TvCatalogRow(
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
              CatalogKitActionChip(
                label: _chipLabel(scope, actions[i]),
                icon: _iconFor(actions[i]),
                selected: _isSelected(scope, actions[i]),
                tvTabId: tabId,
                tvRowId: _widgetId,
                tvItemIndex: i,
                onLeftEdge: i == 0 ? null : () {},
                onRightEdge: i == actions.length - 1 ? null : () {},
                onDownEdge: focusDown ?? () {},
                onTap: () => _onAction(context, scope, actions[i]),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  String _chipLabel(CatalogLayoutScope scope, Map<String, dynamic> action) {
    final id = (action['id'] ?? '').toString();
    final base = (action['label'] ?? id).toString();
    final items = catalogKitItemsFromSpec(action);
    if (items.isEmpty) return base;
    final selected = scope.selectedId(id);
    if (selected == null || selected.isEmpty) return base;
    for (final item in items) {
      if (item.id == selected) {
        return selected == 'all' ? base : '$base: ${item.label}';
      }
    }
    return base;
  }

  bool _isSelected(CatalogLayoutScope scope, Map<String, dynamic> action) {
    final id = (action['id'] ?? '').toString();
    final selected = scope.selectedId(id);
    if (selected == null || selected.isEmpty || selected == 'all') return false;
    return catalogKitItemsFromSpec(action).isNotEmpty;
  }

  IconData? _iconFor(Map<String, dynamic> action) {
    final name = (action['icon'] ?? '').toString().trim().toLowerCase();
    return switch (name) {
      'refresh' => Icons.refresh,
      'search' => Icons.search,
      'filter' || 'catalog' => Icons.filter_list,
      'schedule' || 'time' || 'horizon' => Icons.schedule,
      _ => null,
    };
  }

  Future<void> _onAction(
    BuildContext context,
    CatalogLayoutScope scope,
    Map<String, dynamic> action,
  ) async {
    final id = (action['id'] ?? '').toString();
    final verb = (action['action'] ?? '').toString().trim().toLowerCase();
    if (verb == 'refresh') {
      onRefresh?.call();
      return;
    }
    if (verb == 'search') {
      return;
    }

    final items = catalogKitItemsFromSpec(action);
    if (items.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ForjaShellColors.surfaceElevated,
      builder: (ctx) {
        final selected = scope.selectedId(id);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.label),
                  trailing: selected == item.id
                      ? const Icon(
                          Icons.check,
                          color: ForjaShellColors.brandGreen,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, item.id),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    scope.onSelect(id, picked, toggle: false);
  }
}
