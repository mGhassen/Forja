import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/player/sources/kit_sources.dart';
import 'package:forja/shared/engine/hub/kit_panel_source_flags_hooks.dart';

/// Settings → kit panel source flags (RFC-095).
abstract final class SettingsKitHooksRegister {
  SettingsKitHooksRegister._();

  static void ensureRegistered() {
    KitPanelSourceFlagsHooks.warm = (ref) async {
      if (ref is! WidgetRef && ref is! Ref) return;
      final r = ref as dynamic;
      await r.read(settingsPlaybackProvider.future);
    };
    KitPanelSourceFlagsHooks.watch = (ref) {
      if (ref is! WidgetRef) return null;
      final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
      if (snap == null) return null;
      return KitPanelSourceFlags(
        torrent: snap.playSourceTorrent,
        stremio: snap.playSourceStremio,
        nuvio: snap.playSourceNuvio,
        engine: snap.playSourceEngine,
      );
    };
  }
}
