import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';

const kKitListOpenModeDefault = 'panel';

/// Read kit.list `openSetting` (e.g. Live Sports `matchOpen`) from pack prefs.
Future<String> resolveListOpenMode({
  required String pluginId,
  required String? openSettingId,
  required String layoutOpen,
}) async {
  final field = (openSettingId ?? '').trim();
  final fallback = layoutOpen.trim().isEmpty
      ? kKitListOpenModeDefault
      : layoutOpen.trim().toLowerCase();
  if (field.isEmpty || pluginId.trim().isEmpty) return fallback;
  final raw = await PackSettingsStore.getString(
    pluginId,
    field,
    defaultValue: fallback,
  );
  final v = raw.trim().toLowerCase();
  return v.isEmpty ? fallback : v;
}

/// Listenable that bumps when pack settings change (open mode, etc.).
ValueListenable<int> get packSettingsRevisionListenable =>
    PackSettingsStore.revision;
