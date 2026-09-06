import 'package:flutter/material.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_hub_page.dart';
import 'package:forja/features/live_matches/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';

/// Full-page Live Sports host mounted from CatalogShell when pack layout
/// declares `kit.list` with this feature's opaque source id (RFC-085).
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

  /// True when [roots] include `kit.list` with Live Sports source id.
  static bool matchesLayout(Iterable<Map<String, dynamic>> roots) =>
      CatalogKitTypes.treeContains(
        roots,
        slot: CatalogKitTypes.list,
        listSource: LiveSportsHost.listSourceId,
      );

  @override
  Widget build(BuildContext context) => LiveSportsHubPage(
        layoutWidgets: layoutWidgets,
        parentShellVisible: shellTabVisible,
        refreshEpoch: refreshEpoch,
      );
}
