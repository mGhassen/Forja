import 'package:flutter/widgets.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_hub_page.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_kit_page.dart';
import 'package:forja/features/live_matches/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';

/// Host-default kit layout when no Live Sports hub pack contributes `layout`.
///
/// Dense list + feature source id; streams panel is host chrome on select
/// (RFC-084). Packs may replace this tree via CatalogShell.
const List<Map<String, dynamic>> kLiveSportsHostDefaultLayout = [
  {
    'type': CatalogKitTypes.list,
    'id': 'schedule',
    'source': LiveSportsHost.listSourceId,
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
