import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/services/pack/pack_settings_store.dart';

/// Default pack open mode when layout has no stored setting.
const kKitListOpenModeDefault = 'panel';

/// Watches [PackSettingsStore.revision] so Addon select changes rebuild the list.
final packSettingsRevisionProvider = Provider<int>((ref) {
  final n = PackSettingsStore.revision;
  void listener() => ref.invalidateSelf();
  n.addListener(listener);
  ref.onDispose(() => n.removeListener(listener));
  return n.value;
});

/// Pack setting string for kit.list `openSetting` (e.g. `matchOpen`).
///
/// Family key: `(pluginId, fieldId)`. Default [kKitListOpenModeDefault].
final kitListOpenModeProvider =
    FutureProvider.autoDispose.family<String, ({String pluginId, String fieldId})>(
  (ref, key) async {
    ref.watch(packSettingsRevisionProvider);
    final pluginId = key.pluginId.trim();
    final fieldId = key.fieldId.trim();
    if (pluginId.isEmpty || fieldId.isEmpty) {
      return kKitListOpenModeDefault;
    }
    return PackSettingsStore.getString(
      pluginId,
      fieldId,
      defaultValue: kKitListOpenModeDefault,
    );
  },
);
