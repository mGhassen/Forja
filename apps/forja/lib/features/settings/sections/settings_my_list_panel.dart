import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';
import 'package:forja/shared/engine/lists/list_open_prefs.dart';
import 'package:forja/shared/engine/models/models.dart';

/// My List open defaults — rows/options come from **installed** details hubs only.
///
/// No fixed Films / Anime / Asian Drama inventory. Engine-type tokens are the
/// union of `types[]` on kit plugins that have `details` (pack-agnostic).
class SettingsMyListPanel extends StatefulWidget {
  const SettingsMyListPanel({super.key});

  @override
  State<SettingsMyListPanel> createState() => _SettingsMyListPanelState();
}

class _SettingsMyListPanelState extends State<SettingsMyListPanel> {
  /// Opaque types that are not My List → details open targets.
  static const _skipTypes = {
    'list',
    'live_match',
    'live_sport',
    'live',
    'catalog',
  };

  Map<String, String> _defaults = {};
  List<EnginePlugin> _hubs = const [];
  List<String> _types = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final hubs = <EnginePlugin>[];
    final typeSet = <String>{};
    for (final pl in await PluginNavRegistry.listKitPlugins()) {
      if (!pl.hasCapability('details')) continue;
      if (pl.types.length == 1 && pl.types.first == 'list') continue;
      hubs.add(pl);
      for (final t in pl.types) {
        final token = t.trim();
        if (token.isEmpty || _skipTypes.contains(token)) continue;
        typeSet.add(token);
      }
    }
    hubs.sort(
      (a, b) => _label(a).toLowerCase().compareTo(_label(b).toLowerCase()),
    );
    final types = typeSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final defaults = await ListOpenPrefs.allDefaults();
    if (!mounted) return;
    setState(() {
      _hubs = hubs;
      _types = types;
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

  /// Prefer installed hub nav label(s) — never a hardcoded product taxonomy.
  String _typeTitle(String type) {
    final hubs = _hubsForType(type);
    if (hubs.isEmpty) return type;
    if (hubs.length == 1) return _label(hubs.first);
    return hubs.map(_label).join(' · ');
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_hubs.isEmpty || _types.isEmpty) {
      return SettingsGroup(
        label: 'My List open hubs',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Install a catalog hub with details to link My List opens. '
              'Defaults appear from whatever hubs you have enabled.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }
    return SettingsGroup(
      label: 'My List open hubs',
      children: [
        for (final type in _types)
          SettingsSelectRow(
            title: _typeTitle(type),
            subtitle:
                'Default for list rows of type “$type” when no hub is saved yet',
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
