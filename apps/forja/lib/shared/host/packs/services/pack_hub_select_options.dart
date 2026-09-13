import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/host/packs/services/pack_addon_settings_spec.dart';

/// Resolve [PackAddonSettingsFieldType.hubSelect] options from installed hubs.
abstract final class PackHubSelectOptions {
  PackHubSelectOptions._();

  static const skipTypes = {
    'list',
    'live_match',
    'live_sport',
    'live',
    'catalog',
    'iptv',
  };

  /// Shell browse hub: `nav` + `details`. Details-only packs (e.g. IPTV VOD) are not hubs.
  static bool isBrowseHub(EnginePlugin pl) {
    if (!pl.isKitPlugin || !pl.hasCapability('details')) return false;
    if (pl.nav == null || pl.nav!.isEmpty) return false;
    if (pl.types.every(skipTypes.contains)) return false;
    if (pl.types.length == 1 && pl.types.first == 'list') return false;
    return true;
  }

  static String labelFor(EnginePlugin pl) {
    final nav = pl.nav;
    if (nav != null) {
      final label = nav['label']?.toString().trim() ?? '';
      if (label.isNotEmpty) return label;
    }
    final name = pl.name.trim();
    return name.isNotEmpty ? name : pl.id;
  }

  /// Auto + installed browse hubs matching [field.hubTypes] (or all if empty).
  static Future<List<PackAddonSettingsOption>> optionsFor(
    PackAddonSettingsField field,
  ) async {
    final want = field.hubTypes
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !skipTypes.contains(t))
        .toSet();
    final out = <PackAddonSettingsOption>[
      const PackAddonSettingsOption(id: '', label: 'Auto'),
    ];
    final hubs = <EnginePlugin>[];
    for (final pl in await PluginNavRegistry.listKitPlugins()) {
      if (!isBrowseHub(pl)) continue;
      if (want.isNotEmpty && !pl.types.any(want.contains)) continue;
      hubs.add(pl);
    }
    hubs.sort(
      (a, b) => labelFor(a).toLowerCase().compareTo(labelFor(b).toLowerCase()),
    );
    for (final pl in hubs) {
      out.add(PackAddonSettingsOption(id: pl.id, label: labelFor(pl)));
    }
    return out;
  }
}
