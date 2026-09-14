import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/host/packs/services/pack_addon_settings_spec.dart';
import 'package:forja/shared/host/packs/services/pack_settings_store.dart';

/// Pack-only gate for Forja Sports / Live TV (RFC-096).
///
/// No leagues, category maps, or portal arming — only `forjaSportsEnabled`.
abstract final class IptvForjaSportsGate {
  IptvForjaSportsGate._();

  static const fieldForjaSports = 'forjaSportsEnabled';

  /// Enabled hub plugin that declares the Forja Sports toggle.
  static Future<String?> resolveSettingsPluginId() async {
    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (!p.enabled) continue;
        final spec = PackAddonSettingsSpec.fromPlugin(p);
        if (spec == null) continue;
        final hasToggle = spec.fields.any((f) => f.id == fieldForjaSports);
        if (hasToggle) return p.id;
      }
    }
    return null;
  }

  static Future<bool> isForjaSportsEnabled() async {
    final pluginId = await resolveSettingsPluginId();
    if (pluginId == null) return true;
    return PackSettingsStore.getBool(
      pluginId,
      fieldForjaSports,
      defaultValue: true,
    );
  }
}
