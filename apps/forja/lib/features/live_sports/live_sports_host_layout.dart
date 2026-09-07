import 'package:flutter/widgets.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/host/catalog_shell.dart';

/// Host-default kit layout when no Live Sports hub pack contributes `layout`.
///
/// Dense list + feature source id; streams panel via registry + kit list
/// (RFC-084). Packs may replace this tree via CatalogShell.
const List<Map<String, dynamic>> kLiveSportsHostDefaultLayout = [
  {
    'type': CatalogKitTypes.list,
    'id': 'schedule',
    'source': LiveSportsHost.listSourceId,
    'style': 'list',
    'expand': true,
    'kindMenu': 'kind',
  },
];

/// Core shell builder for [live_matches] — CatalogShell + host layout (no pack).
Widget liveSportsCoreTabBuilder() => CatalogShell(
      pluginId: '',
      tabId: LiveSportsHost.tabId,
      hostLayout: kLiveSportsHostDefaultLayout,
    );
