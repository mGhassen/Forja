import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_focus.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';
import 'package:forja/shared/catalog/services/host_list_registry.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/chrome/shell_focusable_tap.dart';

/// Layout widget [`kit.categoryBar`] — horizontal kind / filter chips.
///
/// Spec:
/// ```json
/// {
///   "type": "kit.categoryBar",
///   "id": "kind",
///   "items": [{ "id": "all", "label": "All" }],
///   "source": "live_schedule",
///   "dynamic": true
/// }
/// ```
///
/// When [dynamic] is true and [source] resolves a [CatalogKitListSource], unique
/// entry kinds are appended after static [items] (with an `all` chip first).
class CatalogKitCategoryBar extends ConsumerWidget {
  const CatalogKitCategoryBar({
    super.key,
    required this.tabId,
    required this.spec,
    this.pluginId = '',
    this.sortOrder = 0,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final String pluginId;
  final int sortOrder;

  String get _widgetId => (spec['id'] ?? 'kind').toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = CatalogLayoutScope.of(context);
    final staticItems = catalogKitItemsFromSpec(spec);
    final dynamic = spec['dynamic'] == true;
    final sourceId = (spec['source'] ?? '').toString().trim();

    var kinds = <({String id, String label})>[
      for (final i in staticItems) i,
    ];

    if (dynamic) {
      final source = CatalogHostListRegistry.resolve(
        sourceId: sourceId.isEmpty ? null : sourceId,
        pluginId: pluginId.isEmpty ? null : pluginId,
      );
      if (source != null) {
        final status =
            scope.selectedId('status') ??
            spec['defaultStatus']?.toString() ??
            'plantowatch';
        final pageAsync = source.watchPage(ref, status);
        final page = pageAsync.asData?.value;
        if (page != null) {
          final found = <String>{};
          for (final e in page.entriesForKind(null)) {
            final k = e.kind.trim();
            if (k.isEmpty || k == 'all' || k == 'live_match') continue;
            found.add(k);
          }
          final sorted = found.toList()..sort();
          final haveAll = kinds.any((i) => i.id == 'all');
          if (!haveAll) {
            kinds = [(id: 'all', label: 'All'), ...kinds];
          }
          final existing = {for (final i in kinds) i.id};
          for (final id in sorted) {
            if (existing.contains(id)) continue;
            kinds.add((
              id: id,
              label: id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}',
            ));
          }
        }
      }
    }

    if (kinds.isEmpty) return const SizedBox.shrink();

    final selected = scope.selectedId(_widgetId) ??
        spec['default']?.toString() ??
        kinds.first.id;
    final focusDown = catalogKitFocusEdge(tabId, spec['focusDown']?.toString());
    final focusUp = catalogKitFocusEdge(
      tabId,
      spec['focusUp']?.toString(),
      last: true,
    );

    return TvCatalogRow(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: sortOrder,
      itemCount: kinds.length,
      onFocusUp: focusUp ?? () {},
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: ShellTokens.compactChromeLeadingInset(context),
            vertical: 8,
          ),
          itemCount: kinds.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = kinds[i];
            final on = selected == item.id;
            return shellFocusableTap(
              context: context,
              onTap: () =>
                  scope.onSelect(_widgetId, item.id, toggle: false),
              listIndex: i,
              tvTabId: tabId,
              tvRowId: _widgetId,
              tvItemIndex: i,
              onDownEdge: focusDown ?? () {},
              child: ForjaShellChip(
                label: item.label,
                selected: on,
              ),
            );
          },
        ),
      ),
    );
  }
}
