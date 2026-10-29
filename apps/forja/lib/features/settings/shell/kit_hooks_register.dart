import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/engine/runtime/vm/service.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/sources/torrent_js_search.dart';
import 'package:forja/shared/player/sources/kit/panel_source_flags.dart';
import 'package:rust/rust.dart';

/// Settings → kit panel source flags (RFC-095).
abstract final class SettingsKitHooksRegister {
  SettingsKitHooksRegister._();

  static void ensureRegistered() {
    KitPanelSourceFlagsHooks.warm = (ref) async {
      if (ref is! WidgetRef && ref is! Ref) return;
      final r = ref as dynamic;
      await r.read(settingsPlaybackProvider.future);
      // Warm chip inventories so Sources paints packs/addons on frame 0.
      unawaited(EngineService.instance.listSourcesPanelPacks());
      unawaited(syncTorrentSearchCatalog());
      unawaited(NuvioService.instance.listSourcesPanelAddons());
      unawaited(StremioService().getAddonsForResource('stream'));
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
