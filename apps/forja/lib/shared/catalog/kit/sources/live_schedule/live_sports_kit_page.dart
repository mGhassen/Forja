import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/live_sports_hub_page.dart';

/// Full-page host for `kit.list { source: live_schedule }` (RFC-071).
///
/// Pack declares generic kit layout; this page owns mode/schedule/play chrome.
class LiveSportsKitPage extends StatelessWidget {
  const LiveSportsKitPage({
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

  /// True when [roots] include `kit.list` with `source: live_schedule`.
  static bool matchesLayout(Iterable<Map<String, dynamic>> roots) =>
      CatalogKitTypes.treeContains(
        roots,
        slot: CatalogKitTypes.list,
        listSource: CatalogKitListSources.liveSchedule,
      );

  @override
  Widget build(BuildContext context) => LiveSportsHubPage(
        layoutWidgets: layoutWidgets,
        parentShellVisible: shellTabVisible,
        refreshEpoch: refreshEpoch,
      );
}
