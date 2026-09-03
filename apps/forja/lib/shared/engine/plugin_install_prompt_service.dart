import 'package:forja/shared/engine/lean_apply_result.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';
import 'package:forja/shell/shell_bus.dart';

/// Enqueue mid-session install/uninstall confirms from a cloud lean diff.
abstract final class PluginInstallPromptService {
  static Future<void> enqueueFromLeanDiff(LeanApplyResult diff) async {
    if (diff.isEmpty) return;
    if (PluginInstallCoordinator.instance.isBootWarm) return;

    final registry = PluginRegistry.instance;
    final packs = await registry.listPacksRaw();
    final byUrl = {for (final p in packs) p.sourceUrl: p};

    for (final row in diff.added) {
      final url = row.manifestUrl.trim();
      if (url.isEmpty) continue;
      if (await DeferredRemoteInstallStore.contains(url)) continue;
      final local = byUrl[url];
      if (local != null && !await registry.packNeedsDiskInstall(local)) {
        continue;
      }
      ShellBus.enqueuePluginInstall(
        PluginInstallPrompt(
          manifestUrl: url,
          displayName: row.name ?? local?.name,
          source: PluginInstallSource.remoteProfile,
          kind: PluginPackPromptKind.install,
        ),
      );
    }

    for (final row in diff.removed) {
      final url = row.manifestUrl.trim();
      if (url.isEmpty) continue;
      if (await PendingRemotePurgeStore.contains(url)) continue;
      final local = byUrl[url];
      if (local == null) continue;
      ShellBus.enqueuePluginInstall(
        PluginInstallPrompt(
          manifestUrl: url,
          displayName: row.name ?? local.name,
          source: PluginInstallSource.remoteProfile,
          kind: PluginPackPromptKind.uninstall,
        ),
      );
    }
  }
}
