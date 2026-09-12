import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';
import 'package:forja/shared/engine/lists/list_open_prefs.dart';
import 'package:forja/shared/engine/models/models.dart';

/// Default hub per engine type for My List open binding (RFC-108).
class SettingsMyListPanel extends StatefulWidget {
  const SettingsMyListPanel({super.key});

  @override
  State<SettingsMyListPanel> createState() => _SettingsMyListPanelState();
}

class _SettingsMyListPanelState extends State<SettingsMyListPanel> {
  static const _types = <String>['movie', 'tv', 'anime', 'drama'];

  Map<String, String> _defaults = {};
  List<EnginePlugin> _hubs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final hubs = <EnginePlugin>[];
    for (final pl in await PluginNavRegistry.listKitPlugins()) {
      if (!pl.hasCapability('details')) continue;
      if (pl.types.length == 1 && pl.types.first == 'list') continue;
      hubs.add(pl);
    }
    hubs.sort(
      (a, b) => _label(a).toLowerCase().compareTo(_label(b).toLowerCase()),
    );
    final defaults = await ListOpenPrefs.allDefaults();
    if (!mounted) return;
    setState(() {
      _hubs = hubs;
      _defaults = defaults;
      _loading = false;
    });
  }

  String _label(EnginePlugin pl) {
    final nav = pl.nav;
    if (nav != null) {
      final label = nav['label']?.toString().trim() ?? '';
      if (label.isNotEmpty) return label;
    }
    final name = pl.name.trim();
    return name.isNotEmpty ? name : pl.id;
  }

  List<EnginePlugin> _hubsForType(String type) => [
        for (final pl in _hubs)
          if (pl.types.contains(type)) pl,
      ];

  String _displayForType(String type) {
    final id = _defaults[type]?.trim() ?? '';
    if (id.isEmpty) return 'Auto';
    for (final pl in _hubs) {
      if (pl.id == id) return _label(pl);
    }
    return 'Auto';
  }

  Future<void> _setType(String type, String? display) async {
    if (display == null || display == 'Auto') {
      await ListOpenPrefs.setDefaultPluginId(type, null);
    } else {
      String? id;
      for (final pl in _hubsForType(type)) {
        if (_label(pl) == display) {
          id = pl.id;
          break;
        }
      }
      await ListOpenPrefs.setDefaultPluginId(type, id);
    }
    await _reload();
  }

  String _typeTitle(String type) => switch (type) {
        'movie' => 'Films',
        'tv' => 'Series',
        'anime' => 'Anime',
        'drama' => 'Asian Drama',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SettingsGroup(
      label: 'My List open defaults',
      children: [
        for (final type in _types)
          SettingsSelectRow(
            title: _typeTitle(type),
            subtitle:
                'Used when a list row has matching ids and no saved hub yet',
            value: _displayForType(type),
            options: [
              'Auto',
              ..._hubsForType(type).map(_label),
            ],
            onChanged: (v) => _setType(type, v),
          ),
      ],
    );
  }
}
