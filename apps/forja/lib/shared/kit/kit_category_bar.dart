import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/kit/kit_category_circle_meta.dart';
import 'package:forja/shared/kit/kit_focus.dart';
import 'package:forja/shared/kit/kit_layout_scope.dart';
import 'package:forja/shared/kit/kit_list_source.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/shell_mood_circle.dart';
import 'package:forja/shared/kit/host_list_registry.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

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
class KitCategoryBar extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<KitCategoryBar> createState() => _KitCategoryBarState();
}

class _KitCategoryBarState extends ConsumerState<KitCategoryBar> {
  KitListPage? _dynamicPage;

  String get _widgetId => (widget.spec['id'] ?? 'kind').toString();

  void _applyPage(KitListPage? page) {
    if (!mounted || identical(page, _dynamicPage)) return;
    setState(() => _dynamicPage = page);
  }

  @override
  Widget build(BuildContext context) {
    final scope = KitLayoutScope.of(context);
    final staticItems = kitItemsFromSpec(widget.spec);
    final dynamic = widget.spec['dynamic'] == true;
    final sourceId = (widget.spec['source'] ?? '').toString().trim();

    final kindIcons = kitCategoryBarKindIcons(widget.spec);
    var kinds = <({String id, String label, String? icon})>[
      for (final i in staticItems)
        (id: i.id, label: i.label, icon: kindIcons[i.id.toLowerCase()]),
    ];

    if (dynamic) {
      final source = HostListRegistry.resolve(
        sourceId: sourceId.isEmpty ? null : sourceId,
        pluginId: widget.pluginId.isEmpty ? null : widget.pluginId,
      );
      if (source != null) {
        final status =
            scope.selectedId('status') ??
            widget.spec['defaultStatus']?.toString() ??
            'plantowatch';
        // Do not [watchPage] here — KitListWidget watches the same provider.
        // Dual watch flushes listeners mid-list-build → markNeedsBuild during build.
        source.listenPage(ref, status, (async) {
          // Keep last kinds during reload — null page collapses the bar and
          // the Expanded list jumps into that gap (cards flash over chrome).
          final page = async.asData?.value ?? async.valueOrNull;
          if (page == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyPage(page);
          });
        });
        final seedPage = source.readPage(ref, status);
        final seed = seedPage.asData?.value ?? seedPage.valueOrNull;
        if (_dynamicPage == null && seed != null) {
          _dynamicPage = seed;
        }
        final page = _dynamicPage;
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
            kinds = [
              (
                id: 'all',
                label: 'All',
                icon: kindIcons['all'] ?? 'grid',
              ),
              ...kinds,
            ];
          }
          final existing = {for (final i in kinds) i.id};
          for (final id in sorted) {
            if (existing.contains(id)) continue;
            kinds.add((
              id: id,
              label: catalogKitCategoryLabel(id),
              icon: kindIcons[id.toLowerCase()],
            ));
          }
        }
      }
    }

    if (kinds.isEmpty) return const SizedBox.shrink();

    final selected = scope.selectedId(_widgetId) ??
        widget.spec['default']?.toString() ??
        kinds.first.id;
    final focusDownId = (widget.spec['focusDown'] ?? '').toString().trim();
    final focusUp = kitFocusEdge(
      widget.tabId,
      widget.spec['focusUp']?.toString(),
      last: true,
    );
    final focusLeft = kitFocusSide(widget.tabId, widget.spec['focusLeft']);
    final focusRight = kitFocusSide(widget.tabId, widget.spec['focusRight']);
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
            final meta = kitMoodCircleMeta(id: item.id, icon: item.icon);
            final on = selected == item.id;
            return ShellMoodCircleItem(
              layout: layout,
              label: catalogKitCategoryLabel(item.id, label: item.label),
              icon: meta.icon,
              accent: meta.accent,
              selected: on,
              listIndex: i,
              tvTabId: widget.tabId,
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
                  kitFocusEdge(widget.tabId, focusDownId, last: true),
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
              tabId: widget.tabId,
              rowId: _widgetId,
              sortOrder: widget.sortOrder,
              itemCount: kinds.length,
              resultsRowId: resultsRowId,
              onFocusLeft: focusLeft,
              onFocusRight: focusRight,
              builder: (context, edgesFor) => centeredRow(
                edgesFor: edgesFor,
                scaleToFit: true,
              ),
            );
          }

          // Overflow: scale to fit and keep centered.
          return centeredRow(
            scaleToFit:
                layout.contentWidth(kinds.length) > constraints.maxWidth,
          );
        },
      ),
    );
  }
}
