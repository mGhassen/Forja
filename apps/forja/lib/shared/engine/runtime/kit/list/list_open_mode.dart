import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kKitListOpenModeDefault = 'panel';

/// Host wires pack settings revision + string read (e.g. PackSettingsStore).
abstract final class KitListOpenModeHooks {
  KitListOpenModeHooks._();

  /// Revision listenable — bump invalidates [kitListOpenModeProvider].
  static ValueListenable<int>? revision;

  /// Read pack setting string for kit.list `openSetting`.
  static Future<String> Function(
    String pluginId,
    String fieldId, {
    required String defaultValue,
  })? getString;

  static void clear() {
    revision = null;
    getString = null;
  }
}

final packSettingsRevisionProvider = Provider<int>((ref) {
  final n = KitListOpenModeHooks.revision;
  if (n == null) return 0;
  void listener() => ref.invalidateSelf();
  n.addListener(listener);
  ref.onDispose(() => n.removeListener(listener));
  return n.value;
});

/// Pack setting string for kit.list `openSetting` (e.g. `matchOpen`).
final kitListOpenModeProvider = FutureProvider.autoDispose
    .family<String, ({String pluginId, String fieldId})>((ref, key) async {
  ref.watch(packSettingsRevisionProvider);
  final pluginId = key.pluginId.trim();
  final fieldId = key.fieldId.trim();
  if (pluginId.isEmpty || fieldId.isEmpty) {
    return kKitListOpenModeDefault;
  }
  final read = KitListOpenModeHooks.getString;
  if (read == null) return kKitListOpenModeDefault;
  return read(
    pluginId,
    fieldId,
    defaultValue: kKitListOpenModeDefault,
  );
});
