import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/services/pack/pack_addon_settings_spec.dart';
import 'package:forja/shared/foundation/services/pack/pack_settings_store.dart';

/// Pack Setup toggle: collapse same fixture across catalogs (Catalog = All).
///
/// Default **on** when no hub declares the field (e.g. Cards-only install).
abstract final class LiveMergeMatchingGate {
  LiveMergeMatchingGate._();

  static const fieldMergeMatching = 'mergeMatchingEvents';

  static Future<String?> resolveSettingsPluginId() async {
    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (!p.enabled) continue;
        final spec = PackAddonSettingsSpec.fromPlugin(p);
        if (spec == null) continue;
        if (spec.fields.any((f) => f.id == fieldMergeMatching)) {
          return p.id;
        }
      }
    }
    return null;
  }

  static Future<bool> isEnabled() async {
    final pluginId = await resolveSettingsPluginId();
    if (pluginId == null) return true;
    return PackSettingsStore.getBool(
      pluginId,
      fieldMergeMatching,
      defaultValue: true,
    );
  }
}
