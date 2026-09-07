import 'package:flutter/widgets.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/foundation/components/layout/kit_types.dart';
import 'package:forja/shared/foundation/blocks/shell/kit_shell.dart';

/// Host-default kit layout when no Live Sports hub pack contributes `layout`.
///
/// Composes generic kit primitives only (same shape as the list+panel pack).
const List<Map<String, dynamic>> kLiveSportsHostDefaultLayout = [
  {
    'type': KitTypes.stack,
    'id': 'page',
    'expand': true,
    'children': [
      {
        'type': KitTypes.topBar,
        'id': 'chrome',
        'focusDown': 'kind',
        'actions': [
          {
            'id': 'catalog',
            'label': 'Catalog',
            'icon': 'filter',
            'items': [
              {'id': 'all', 'label': 'All'},
            ],
            'dynamicCatalogs': true,
          },
          {
            'id': 'horizon',
            'label': 'Schedule',
            'icon': 'schedule',
            'items': [
              {'id': 'live', 'label': 'Live now'},
              {'id': '1h', 'label': '1 hour'},
              {'id': '3h', 'label': '3 hours'},
              {'id': '6h', 'label': '6 hours'},
              {'id': '12h', 'label': '12 hours'},
              {'id': '24h', 'label': '24 hours'},
              {'id': 'all', 'label': 'All'},
            ],
          },
          {
            'id': 'refresh',
            'label': 'Refresh',
            'icon': 'refresh',
            'action': 'refresh',
          },
        ],
      },
      {
        'type': KitTypes.categoryBar,
        'id': 'kind',
        'source': LiveSportsHost.listSourceId,
        'dynamic': true,
        'default': 'all',
        'focusUp': 'chrome',
        'focusDown': 'schedule',
      },
      {
        'type': KitTypes.list,
        'id': 'schedule',
        'source': LiveSportsHost.listSourceId,
        'style': 'list',
        'open': 'panel',
        'expand': true,
        'kindMenu': 'kind',
        'catalogMenu': 'catalog',
        'horizonMenu': 'horizon',
      },
    ],
  },
];

/// Core shell builder for [live_matches] — KitShell + host layout (no pack).
Widget liveSportsCoreTabBuilder() => KitShell(
      pluginId: '',
      tabId: LiveSportsHost.tabId,
      hostLayout: kLiveSportsHostDefaultLayout,
    );
