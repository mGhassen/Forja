import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/components/chrome/kit_category_circle_meta.dart';
import 'package:forja/shared/foundation/components/layout/kit_focus.dart';
import 'package:forja/shared/foundation/components/layout/kit_layout_scope.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/chrome/shell_mood_circle.dart';

/// Layout widget [`kit.categoryBar`] — [ShellMoodCircle] kind pickers.
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
/// When [dynamic] is true and [source] resolves a [KitListSource], unique
/// entry kinds are appended after static [items] (with an `all` chip first).
class KitCategoryBar extends ConsumerWidget {
  const KitCategoryBar({
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
    final scope = KitLayoutScope.of(context);
    final staticItems = kitItemsFromSpec(spec);
    final dynamic = spec['dynamic'] == true;
    final sourceId = (spec['source'] ?? '').toString().trim();

    var kinds = <({String id, String label})>[
      for (final i in staticItems) i,
    ];

    if (dynamic) {
      final source = HostListRegistry.resolve(
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
              label: catalogKitCategoryLabel(id),
            ));
          }
        }
      }
    }

    if (kinds.isEmpty) return const SizedBox.shrink();

    final selected = scope.selectedId(_widgetId) ??
        spec['default']?.toString() ??
        kinds.first.id;
    final focusDownId = (spec['focusDown'] ?? '').toString().trim();
    final focusUp = kitFocusEdge(
      tabId,
      spec['focusUp']?.toString(),
      last: true,
    );
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final resultsRowId =
        focusDownId.isEmpty ? '$_widgetId-results' : focusDownId;

    return Padding(
      padding: EdgeInsets.only(
        left: ShellTokens.compactChromeLeadingInset(context),
        right: ShellTokens.bodyHorizontalPadding,
        top: 2,
        bottom: 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = ShellMoodCircleLayout.resolve(
            context,
            itemCount: kinds.length,
            maxWidth: constraints.maxWidth,
          );

          Widget circleAt(int i, {TvChipEdges? edges}) {
            final item = kinds[i];
            final meta = catalogKitCategoryCircleMeta(item.id);
            final on = selected == item.id;
            return ShellMoodCircleItem(
              layout: layout,
              label: catalogKitCategoryLabel(item.id, label: item.label),
              icon: meta.icon,
              accent: meta.accent,
              selected: on,
              listIndex: i,
              tvTabId: tabId,
              tvRowId: _widgetId,
              onTap: () {
                if (!on) {
                  scope.onSelect(_widgetId, item.id, toggle: false);
                } else if (tvFocus) {
                  edges?.onSelectAlreadySelected();
                }
              },
              onLeftEdge: edges?.onLeft,
              onRightEdge: edges?.onRight,
              onDownEdge: edges?.onDown ??
                  kitFocusEdge(tabId, focusDownId),
              onUpEdge: focusUp ?? edges?.onUp,
            );
          }

          Widget centeredRow({
            TvChipEdges Function(int index)? edgesFor,
            required bool scaleToFit,
          }) {
            final row = Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < kinds.length; i++) ...[
                  if (i > 0) SizedBox(width: layout.horizontalGap),
                  circleAt(i, edges: edgesFor?.call(i)),
                ],
              ],
            );
            return SizedBox(
              height: layout.rowHeight,
              width: double.infinity,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: scaleToFit
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: row,
                      )
                    : Align(alignment: Alignment.center, child: row),
              ),
            );
          }

          if (tvFocus) {
            return TvChipStrip(
              tabId: tabId,
              rowId: _widgetId,
              sortOrder: sortOrder,
              itemCount: kinds.length,
              resultsRowId: resultsRowId,
              builder: (context, edgesFor) => centeredRow(
                edgesFor: edgesFor,
                scaleToFit: true,
              ),
            );
          }

          // Overflow: scale to fit and keep centered (same as old Live Sports).
          return centeredRow(
            scaleToFit:
                layout.contentWidth(kinds.length) > constraints.maxWidth,
          );
        },
      ),
    );
  }
}
