import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/live_sports_hub_page.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/live_sports_kit_page.dart';
import 'package:flutter/widgets.dart';

/// Host-default kit layout when no Live Sports hub pack contributes `layout`.
///
/// Dense list + `live_schedule` source; streams panel is host chrome on select
/// (RFC-084). Packs may replace this tree via CatalogShell.
const List<Map<String, dynamic>> kLiveSportsHostDefaultLayout = [
  {
    'type': CatalogKitTypes.list,
    'id': 'schedule',
    'source': CatalogKitListSources.liveSchedule,
    'style': 'list',
    'expand': true,
  },
];

/// Core shell builder for [live_matches] — kit mount without a pack plugin id.
Widget liveSportsCoreTabBuilder() => const LiveSportsKitPage(
      pluginId: '',
      tabId: LiveSportsHubPage.tabId,
      layoutWidgets: kLiveSportsHostDefaultLayout,
    );
