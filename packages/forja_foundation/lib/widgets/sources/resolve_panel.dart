import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/panel_tabs.dart';
import 'package:forja_foundation/widgets/sources/sources_panel_chrome.dart';

export 'package:forja_foundation/widgets/sources/sources_types.dart';

/// Resolve streams side-panel chrome — props + load/play callbacks (Zone A).
///
/// Host maps [KitResolveStreamsHooks] / list entry into these props.
class ResolvePanel extends StatelessWidget {
  const ResolvePanel({
    super.key,
    required this.title,
    required this.tabs,
    required this.loadTab,
    required this.onPlayRow,
    this.subtitle,
    this.initialTabId,
    this.browseCategoryTabIds = const {},
    this.onClosed,
    this.onTabsLeftEdge,
    this.reloadNonce = 0,
    this.useFocusableChips = false,
    this.usesTvDensity = false,
    this.tileBuilder,
    this.listFocusWrap,
    this.tabsFocusWrap,
    this.tabsBuilder,
  });

  final String title;
  final String? subtitle;
  final List<SourcesTab> tabs;
  final String? initialTabId;
  final Set<String> browseCategoryTabIds;
  final Future<List<SourcesRow>> Function(
    String tabId, {
    void Function(List<SourcesRow> rows)? onPartial,
    bool force,
  }) loadTab;
  final Future<void> Function(SourcesRow row) onPlayRow;
  final VoidCallback? onClosed;
  final VoidCallback? onTabsLeftEdge;
  final int reloadNonce;
  final bool useFocusableChips;
  final bool usesTvDensity;
  final Widget Function(
    BuildContext context,
    SourcesRow row,
    int index, {
    required bool hideCategorySubtitle,
    required bool upToTabs,
    required VoidCallback onPlay,
  })? tileBuilder;
  final Widget Function(BuildContext context, Widget child, {required int itemCount})?
      listFocusWrap;
  final Widget Function(BuildContext context, Widget child, {required int itemCount})?
      tabsFocusWrap;
  final Widget Function(
    BuildContext context, {
    required String selected,
    required ValueChanged<String> onSelected,
    required List<SourcesTab> tabs,
  })? tabsBuilder;

  /// Build tabs + browse ids from pack layout widgets.
  factory ResolvePanel.fromLayouts({
    Key? key,
    required List<Map<String, dynamic>> layoutWidgets,
    required String title,
    String? subtitle,
    required Future<List<SourcesRow>> Function(
      String tabId, {
      void Function(List<SourcesRow> rows)? onPartial,
      bool force,
    }) loadTab,
    required Future<void> Function(SourcesRow row) onPlayRow,
    VoidCallback? onClosed,
    VoidCallback? onTabsLeftEdge,
    int reloadNonce = 0,
    bool useFocusableChips = false,
    bool usesTvDensity = false,
  }) {
    final chrome = panelChromeFromLayouts(layoutWidgets);
    return ResolvePanel(
      key: key,
      title: title,
      subtitle: subtitle,
      tabs: [
        for (final t in chrome.tabs)
          SourcesTab(id: t.id, label: t.label, icon: t.icon),
      ],
      initialTabId: chrome.initial,
      browseCategoryTabIds: panelBrowseTabIds(chrome.tabs),
      loadTab: loadTab,
      onPlayRow: onPlayRow,
      onClosed: onClosed,
      onTabsLeftEdge: onTabsLeftEdge,
      reloadNonce: reloadNonce,
      useFocusableChips: useFocusableChips,
      usesTvDensity: usesTvDensity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: ForjaShellColors.borderSubtle),
          ),
        ),
        child: SourcesPanelChrome(
          title: title.isEmpty ? 'Streams' : title,
          subtitle: (subtitle ?? '').trim().isEmpty ? null : subtitle!.trim(),
          tabs: tabs,
          initialTabId: initialTabId,
          browseCategoryTabIds: browseCategoryTabIds,
          showInlineSearch: true,
          onClosed: onClosed,
          onTabsLeftEdge: onTabsLeftEdge,
          loadTab: loadTab,
          onPlayRow: onPlayRow,
          reloadNonce: reloadNonce,
          useFocusableChips: useFocusableChips,
          usesTvDensity: usesTvDensity,
          tileBuilder: tileBuilder,
          listFocusWrap: listFocusWrap,
          tabsFocusWrap: tabsFocusWrap,
          tabsBuilder: tabsBuilder,
        ),
      ),
    );
  }
}
