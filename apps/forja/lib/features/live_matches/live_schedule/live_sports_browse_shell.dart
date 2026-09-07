import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/live_matches/catalog/live_schedule_catalog_source.dart';
import 'package:forja/features/live_matches/catalog/live_schedule_filters.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_hub_page.dart';
import 'package:forja/features/live_matches/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_widget.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Host composition for Live Sports — **kit list** + thin chrome + streams panel.
///
/// Browse is [CatalogKitListWidget] (`style: list` → [HubLiveMatchDenseTile]).
/// Play / Providers / Live TV stay in [LiveSportsHubPage] panel-only mode.
class LiveSportsBrowseShell extends ConsumerStatefulWidget {
  const LiveSportsBrowseShell({
    super.key,
    required this.pluginId,
    this.tabId,
    this.layoutWidgets = const [],
    this.shellTabVisible = true,
    this.refreshEpoch = 0,
  });

  final String pluginId;
  final String? tabId;
  final List<Map<String, dynamic>> layoutWidgets;
  final bool shellTabVisible;
  final int refreshEpoch;

  /// True when [roots] include `kit.list` with Live Sports source id.
  static bool matchesLayout(Iterable<Map<String, dynamic>> roots) =>
      CatalogKitTypes.treeContains(
        roots,
        slot: CatalogKitTypes.list,
        listSource: LiveSportsHost.listSourceId,
      );

  @override
  ConsumerState<LiveSportsBrowseShell> createState() =>
      _LiveSportsBrowseShellState();
}

class _LiveSportsBrowseShellState extends ConsumerState<LiveSportsBrowseShell> {
  CatalogKitListEntry? _selected;
  List<String> _sportIds = const [];
  final _layoutSelections = <String, String>{'kind': 'all'};

  Map<String, dynamic> get _listSpec {
    for (final w in widget.layoutWidgets) {
      final type = CatalogKitTypes.normalize((w['type'] ?? '').toString(), w);
      if (type == CatalogKitTypes.list) {
        return Map<String, dynamic>.from(w);
      }
      if (type == CatalogKitTypes.stack) {
        final children = w['children'];
        if (children is! List) continue;
        for (final c in children) {
          if (c is! Map) continue;
          final child = Map<String, dynamic>.from(c);
          if (CatalogKitTypes.normalize(
                (child['type'] ?? '').toString(),
                child,
              ) ==
              CatalogKitTypes.list) {
            return child;
          }
        }
      }
    }
    return {
      'type': CatalogKitTypes.list,
      'id': LiveSportsTvRows.grid,
      'source': LiveSportsHost.listSourceId,
      'style': 'list',
      'expand': true,
      'kindMenu': 'kind',
    };
  }

  @override
  void didUpdateWidget(LiveSportsBrowseShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshEpoch != widget.refreshEpoch) {
      LiveScheduleCatalogSource.instance.invalidateOnRefresh(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabId = (widget.tabId?.trim().isNotEmpty == true)
        ? widget.tabId!.trim()
        : LiveSportsHost.tabId;
    final filters = ref.watch(liveScheduleFiltersProvider);
    final chips = <String>['all', ..._sportIds.where((s) => s != 'all')];
    final listSpec = {
      ..._listSpec,
      'style': 'list',
      'kindMenu': 'kind',
      'source': LiveSportsHost.listSourceId,
    };

    // Drive kind filter into layout scope so CatalogKitListWidget filters entries.
    _layoutSelections['kind'] = filters.sportFilter;

    return CatalogLayoutScope(
      selections: Map.unmodifiable(_layoutSelections),
      widgetSpecs: {
        'kind': {
          'type': CatalogKitTypes.menu,
          'id': 'kind',
          'items': [
            for (final id in chips)
              {'id': id, 'label': id == 'all' ? 'All' : _labelSport(id)},
          ],
        },
      },
      onSelect: (menuId, itemId, {required bool toggle}) {
        setState(() => _layoutSelections[menuId] = itemId);
        if (menuId == 'kind') {
          ref.read(liveScheduleFiltersProvider.notifier).setSportFilter(itemId);
        }
      },
      child: TvFocusGraph(
        tabId: tabId,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chips.length > 1)
              _KitSportChipRow(
                tabId: tabId,
                sports: chips,
                selected: filters.sportFilter,
                onSelect: (id) {
                  ref
                      .read(liveScheduleFiltersProvider.notifier)
                      .setSportFilter(id);
                  setState(() => _layoutSelections['kind'] = id);
                },
              ),
            Expanded(
              child: CatalogKitListWidget(
                tabId: tabId,
                pluginId: widget.pluginId,
                layoutSpec: listSpec,
                refreshEpoch: widget.refreshEpoch,
                selectedEntryId: _selected?.meta.id,
                dynamicKindChips: true,
                onDynamicKinds: (kinds) {
                  final next = kinds.where((k) => k != 'live_match').toList();
                  if (!_sameList(next, _sportIds)) {
                    setState(() => _sportIds = next);
                  }
                },
                onEntrySelected: (entry) {
                  setState(() => _selected = entry);
                  ref.read(liveScheduleSelectedEntryProvider.notifier).state =
                      entry;
                },
                sidePanel: _selected == null
                    ? null
                    : Material(
                        color: ForjaShellColors.surfaceElevated,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: ForjaShellColors.borderSubtle,
                              ),
                            ),
                          ),
                          child: LiveSportsHubPage(
                            key: ValueKey('kit-panel-${_selected!.meta.id}'),
                            layoutWidgets: widget.layoutWidgets,
                            parentShellVisible: widget.shellTabVisible,
                            refreshEpoch: widget.refreshEpoch,
                            panelOnly: true,
                            kitPanelRow: _selected!.legacyRow,
                            onPanelClosed: () {
                              setState(() => _selected = null);
                              ref
                                  .read(
                                    liveScheduleSelectedEntryProvider.notifier,
                                  )
                                  .state = null;
                            },
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _labelSport(String id) {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1);
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _KitSportChipRow extends StatelessWidget {
  const _KitSportChipRow({
    required this.tabId,
    required this.sports,
    required this.selected,
    required this.onSelect,
  });

  final String tabId;
  final List<String> sports;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: ShellTokens.compactChromeLeadingInset(context),
          vertical: 8,
        ),
        itemCount: sports.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = sports[i];
          final label = id == 'all' ? 'All' : _LiveSportsBrowseShellState._labelSport(id);
          final on = selected == id;
          return shellFocusableTap(
            context: context,
            onTap: () => onSelect(id),
            listIndex: i,
            tvTabId: tabId,
            tvRowId: LiveSportsTvRows.sportChips,
            tvItemIndex: i,
            child: ForjaShellChip(
              label: label,
              selected: on,
            ),
          );
        },
      ),
    );
  }
}
