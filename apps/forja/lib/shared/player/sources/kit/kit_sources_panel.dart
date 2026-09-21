import 'package:flutter/material.dart';
import 'package:forja/shared/engine/details/sources_panel_tv.dart';
import 'package:forja/shared/player/sources/torrent/torrent_source_tiles.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/widgets/sources/panel_tabs.dart' show kitPanelTabIcon;
import 'package:forja_foundation/widgets/sources/live_tv_browse.dart';
import 'package:forja_foundation/widgets/sources/sources_panel_chrome.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

export 'package:forja_foundation/widgets/sources/sources_types.dart'
    show SourcesTab, SourcesRow;
export 'package:forja_foundation/widgets/sources/live_tv_browse.dart'
    show
        kSourcesCategoryAll,
        sourcesCategoryKey,
        SourcesCategoryBucket,
        sourcesCategoriesFromRows,
        sourcesFilterByCategory,
        sourcesRowMatchesQuery,
        sourcesFilterByQuery,
        SourcesCategoryRailRow;

typedef KitSourcesTab = SourcesTab;
typedef KitSourcesRow = SourcesRow;

/// Legacy aliases for browse helpers.
const kKitSourcesCategoryAll = kSourcesCategoryAll;
typedef KitSourcesCategoryBucket = SourcesCategoryBucket;
typedef KitSourcesCategoryRailRow = SourcesCategoryRailRow;

String kitSourcesCategoryKey(SourcesRow row) => sourcesCategoryKey(row);
List<SourcesCategoryBucket> kitSourcesCategoriesFromRows(List<SourcesRow> rows) =>
    sourcesCategoriesFromRows(rows);
List<SourcesRow> kitSourcesFilterByCategory(
  List<SourcesRow> rows,
  String selectedKey,
) =>
    sourcesFilterByCategory(rows, selectedKey);
bool kitSourcesRowMatchesQuery(SourcesRow row, String query) =>
    sourcesRowMatchesQuery(row, query);
List<SourcesRow> kitSourcesFilterByQuery(List<SourcesRow> rows, String query) =>
    sourcesFilterByQuery(rows, query);

/// Host wrapper — foundation paint + TV / pill tabs / channel tiles.
class KitSourcesPanel extends StatelessWidget {
  const KitSourcesPanel({
    super.key,
    required this.title,
    required this.tabs,
    required this.loadTab,
    required this.onPlayRow,
    this.subtitle,
    this.initialTabId,
    this.onClosed,
    this.tvTabId,
    this.listRowId = SourcesPanelTv.listRowId,
    this.tabsRowId = SourcesPanelTv.kindRowId,
    this.embedded = false,
    this.showTabs = true,
    this.onTabsLeftEdge,
    this.browseCategoryTabIds = const {},
    this.channelQuery,
    this.onChannelQueryChanged,
    this.showInlineSearch = true,
    this.onLoadingChanged,
    this.reloadNonce = 0,
  });

  final String title;
  final String? subtitle;
  final List<KitSourcesTab> tabs;
  final String? initialTabId;
  final Future<List<KitSourcesRow>> Function(
    String tabId, {
    void Function(List<KitSourcesRow> rows)? onPartial,
    bool force,
  }) loadTab;
  final Future<void> Function(KitSourcesRow row) onPlayRow;
  final VoidCallback? onClosed;
  final String? tvTabId;
  final String listRowId;
  final String tabsRowId;
  final bool embedded;
  final bool showTabs;
  final VoidCallback? onTabsLeftEdge;
  final Set<String> browseCategoryTabIds;
  final String? channelQuery;
  final ValueChanged<String>? onChannelQueryChanged;
  final bool showInlineSearch;
  final ValueChanged<bool>? onLoadingChanged;
  final int reloadNonce;

  static void claimProvidersFocus({
    int maxTries = 24,
    String? forTabId,
  }) {
    SourcesPanelTv.focusKindItem(maxTries: maxTries, forTabId: forTabId);
  }

  String? _effectiveTvTabId(BuildContext context) {
    if (tvTabId != null) return tvTabId;
    if (SourcesPanelTv.isTv(context)) return SourcesPanelTv.tabId;
    return null;
  }

  VoidCallback _listFocusUp(String tvTabId) {
    // Match details: ↑ from stream list → hero. Hub-embedded panels → kind tabs.
    if (tvTabId == MediaDetailsTv.tabId) {
      return () {
        ShellTvFocusCoordinator.focusRowItem(
          tvTabId,
          MediaDetailsTv.heroRowId,
          0,
        );
      };
    }
    return () => SourcesPanelTv.focusKindItem(forTabId: tvTabId);
  }

  void _focusListItem(String? forTabId, {int index = 0}) {
    SourcesPanelTv.focusListItem(index: index, forTabId: forTabId);
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final metrics = ShellScope.metricsOf(context);
    final effectiveTv = _effectiveTvTabId(context);

    return SourcesPanelChrome(
      title: title,
      subtitle: subtitle,
      tabs: tabs,
      loadTab: loadTab,
      onPlayRow: onPlayRow,
      initialTabId: initialTabId,
      onClosed: onClosed,
      listRowId: listRowId,
      tabsRowId: tabsRowId,
      embedded: embedded,
      showTabs: showTabs,
      onTabsLeftEdge: onTabsLeftEdge,
      browseCategoryTabIds: browseCategoryTabIds,
      emptyQueryMessage: browseCategoryTabIds.isEmpty
          ? 'No matches'
          : 'No channels match',
      channelQuery: channelQuery,
      onChannelQueryChanged: onChannelQueryChanged,
      showInlineSearch: showInlineSearch,
      onLoadingChanged: onLoadingChanged,
      reloadNonce: reloadNonce,
      useFocusableChips: policy.useFocusableMoodChips,
      usesTvDensity: metrics.usesTvDensity,
      tabsBuilder: (context, {required selected, required onSelected, required tabs}) {
        return HeroPillSegmentedChoice<String>(
          selected: selected,
          onSelected: onSelected,
          tvTabId: effectiveTv,
          tvRowId: tabsRowId,
          tvItemIndexStart: 0,
          onLeftEdge: onTabsLeftEdge,
          onDownEdge: effectiveTv != null
              ? () => _focusListItem(effectiveTv, index: 0)
              : null,
          segments: [
            for (final tab in tabs)
              HeroPillSegment(
                value: tab.id,
                label: tab.label,
                icon: kitPanelTabIcon(tab.icon),
              ),
          ],
        );
      },
      tabsFocusWrap: effectiveTv == null
          ? null
          : (context, child, {required itemCount}) {
              return TvKitRow(
                tabId: effectiveTv,
                rowId: tabsRowId,
                sortOrder: SourcesPanelTv.kindSort,
                itemCount: itemCount,
                onFocusDown: () => _focusListItem(effectiveTv, index: 0),
                child: child,
              );
            },
      listFocusWrap: effectiveTv == null
          ? null
          : (context, child, {required itemCount}) {
              return TvKitRow(
                tabId: effectiveTv,
                rowId: listRowId,
                sortOrder: SourcesPanelTv.listSort,
                itemCount: itemCount,
                orientation: ShellTvRowOrientation.vertical,
                onFocusUp: _listFocusUp(effectiveTv),
                child: child,
              );
            },
      tileBuilder: (
        context,
        row,
        index, {
        required hideCategorySubtitle,
        required upToTabs,
        required onPlay,
      }) {
        final footer = (row.footer ?? '').trim();
        final provider = hideCategorySubtitle ? null : row.subtitle;
        return SourcesPanelChannelTile(
          title: row.title,
          provider: provider,
          badges: row.badges,
          viewerCount: row.viewerCount,
          footerLabel: footer.isEmpty ? null : footer,
          tvTabId: effectiveTv,
          tvRowId: listRowId,
          tvItemIndex: index,
          onHoverProbe: row.onHoverProbe,
          probeHealthCache: row.probeHealthCache,
          onUpEdge: effectiveTv != null && (upToTabs || index == 0)
              ? _listFocusUp(effectiveTv)
              : null,
          onLeftEdge: onTabsLeftEdge,
          onPlay: onPlay,
        );
      },
    );
  }
}

/// Host expanding search — injects [TvBrowseTextField] when TV.
class KitSourcesExpandingSearch extends StatelessWidget {
  const KitSourcesExpandingSearch({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.focusNode,
    this.debugLabel = 'kit-sources-expanding-search',
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final FocusNode? focusNode;
  final String debugLabel;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return SourcesExpandingSearch(
      query: query,
      onQueryChanged: onQueryChanged,
      focusNode: focusNode,
      debugLabel: debugLabel,
      useTvBrowse: tv,
      fieldBuilder: tv
          ? (context, {
              required controller,
              required focusNode,
              required onChanged,
              required onEscape,
            }) {
              return TvBrowseTextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onEscape: onEscape,
                onSubmitted: (_) => focusNode.unfocus(),
                browsePlaceholder: 'Search channels…',
                browseHintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: ShellTokens.eventSearchFontSizeTv,
                ),
                caretHeight: ShellTokens.eventSearchFontSizeTv * 1.5,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ShellTokens.eventSearchFontSizeTv,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: ShellTokens.torrentPanelSearchPadVTv,
                  ),
                ),
              );
            }
          : null,
    );
  }
}
