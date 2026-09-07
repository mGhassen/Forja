import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forja/features/live_sports/live_prefs.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/host/catalog_shell.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Horizon menu items for Live Sports kit chrome (RFC-073 A06).
const List<Map<String, String>> kLiveSportsHorizonMenuItems = [
  {'id': 'live', 'label': 'Live'},
  {'id': '1h', 'label': '1h'},
  {'id': '3h', 'label': '3h'},
  {'id': '6h', 'label': '6h'},
  {'id': '12h', 'label': '12h'},
  {'id': '24h', 'label': '24h'},
  {'id': 'all', 'label': 'All'},
];

/// Host-default kit layout when no Live Sports hub pack contributes `layout`.
List<Map<String, dynamic>> liveSportsHostDefaultLayout({
  List<Map<String, String>> catalogItems = const [
    {'id': 'all', 'label': 'All'},
  ],
  String catalogDefault = 'all',
  String horizonDefault = '24h',
}) =>
    [
      {
        'type': CatalogKitTypes.stack,
        'id': 'page',
        'expand': true,
        'children': [
          {
            'type': CatalogKitTypes.menu,
            'id': 'catalog',
            'default': catalogDefault,
            'focusDown': 'horizon',
            'items': catalogItems,
          },
          {
            'type': CatalogKitTypes.menu,
            'id': 'horizon',
            'default': horizonDefault,
            'focusUp': 'catalog',
            'focusDown': 'schedule',
            'items': kLiveSportsHorizonMenuItems,
          },
          {
            'type': CatalogKitTypes.list,
            'id': 'schedule',
            'source': LiveSportsHost.listSourceId,
            'style': 'list',
            'expand': true,
            'kindMenu': 'kind',
            'catalogMenu': 'catalog',
            'horizonMenu': 'horizon',
          },
        ],
      },
    ];

/// Core shell builder for [live_matches] — CatalogShell + host layout (no pack).
Widget liveSportsCoreTabBuilder() => const _LiveSportsCoreTab();

class _LiveSportsCoreTab extends StatefulWidget {
  const _LiveSportsCoreTab();

  @override
  State<_LiveSportsCoreTab> createState() => _LiveSportsCoreTabState();
}

class _LiveSportsCoreTabState extends State<_LiveSportsCoreTab> {
  List<Map<String, dynamic>>? _layout;

  @override
  void initState() {
    super.initState();
    _layout = liveSportsHostDefaultLayout();
    unawaited(_loadChrome());
  }

  Future<void> _loadChrome() async {
    var catalogDefault = 'all';
    var horizonDefault = '24h';
    try {
      final prefs = await SharedPreferences.getInstance();
      final catalog =
          prefs.getString(LivePrefs.catalogFilterKey)?.trim() ?? 'all';
      final schedule =
          prefs.getString(LivePrefs.scheduleKey)?.trim() ?? '24h';
      catalogDefault = catalog.isEmpty ? 'all' : catalog;
      horizonDefault = schedule.isEmpty ? '24h' : schedule;
    } catch (_) {}

    final items = <Map<String, String>>[
      {'id': 'all', 'label': 'All'},
    ];
    try {
      final plugins =
          await EngineService.instance.listEnabledLiveCatalogPlugins();
      for (final p in plugins) {
        items.add({
          'id': EngineService.normalizeLiveSportPluginId(p.id),
          'label': p.name.trim().isEmpty ? p.id : p.name.trim(),
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _layout = liveSportsHostDefaultLayout(
        catalogItems: items,
        catalogDefault: catalogDefault,
        horizonDefault: horizonDefault,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CatalogShell(
      key: ValueKey(_layout.hashCode),
      pluginId: '',
      tabId: LiveSportsHost.tabId,
      hostLayout: _layout ?? liveSportsHostDefaultLayout(),
    );
  }
}
