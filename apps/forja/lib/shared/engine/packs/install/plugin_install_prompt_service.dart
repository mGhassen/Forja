import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/lean_apply_result.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/pack_hub_features.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/install/remote_pack_intent_store.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Apply a cloud lean diff on this device: auto-install adds, toast results.
///
/// Removals are already purged by [PluginRegistry.applyLeanManifestUrls] when
/// `purgeRemovedImmediately` is true.
///
/// **Who owns download:**
/// - Boot / profile splash → [PluginInstallCoordinator.ensureAllInstalled]
///   (`bootWarm` + `awaitCloudLean`). Soft-pull under warm is lean-index only.
/// - Mid-session (shell open, [ShellBus.splashDismissed]) → this path.
///
/// Soft-pull before a profile is launched / profile splash must **not**
/// download or activate hubs — pack scope is not ready yet (issue 259).
abstract final class PluginInstallPromptService {
  /// Mid-session cloud sync: download new packs; toast installs + removals.
  static Future<void> applyCloudLeanDiff(LeanApplyResult diff) async {
    if (diff.isEmpty) return;
    if (PluginInstallCoordinator.instance.isBootWarm) return;

    final coordinator = PluginInstallCoordinator.instance;

    if (diff.removed.isNotEmpty) {
      final labeled = [
        for (final row in diff.removed)
          (row.name?.trim().isNotEmpty == true) ? row.name!.trim() : 'Pack',
      ];
      await coordinator.notifyCloudPacksRemoved(labeled);
    }

    // Profile splash / logo intro hydrate via ensureAllInstalled. Early soft
    // pulls (profile picker, restored-session bg pull before warm) only
    // update lean membership.
    if (!ShellBus.splashDismissed.value) {
      if (diff.added.isNotEmpty) {
        debugPrint(
          '[PluginInstall] defer cloud auto-install '
          '(${diff.added.length} pack(s)) — awaiting splash/profile hydrate',
        );
      }
      return;
    }

    final registry = PluginRegistry.instance;
    final installedNames = <String>[];
    final installedPacks = <EnginePack>[];
    for (final row in diff.added) {
      final url = row.manifestUrl.trim();
      if (url.isEmpty) continue;
      await DeferredRemoteInstallStore.clear(url);
      final packs = await registry.listPacksRaw();
      EnginePack? local;
      for (final p in packs) {
        if (p.sourceUrl == url) {
          local = p;
          break;
        }
      }
      if (local != null && !await registry.packNeedsDiskInstall(local)) {
        continue;
      }
      final label = (row.name ?? local?.name)?.trim();
      try {
        debugPrint('[PluginInstall] cloud auto-install $url');
        final pack = await coordinator.installManifest(url);
        installedPacks.add(pack);
        installedNames.add(
          label?.isNotEmpty == true ? label! : pack.name,
        );
      } catch (e) {
        debugPrint('[PluginInstall] cloud auto-install failed ($url): $e');
      }
    }

    if (installedPacks.isNotEmpty) {
      await PackHubFeatures.refreshAndActivateInstalled(installedPacks);
    }
    if (installedNames.isNotEmpty) {
      await coordinator.notifyCloudPacksInstalled(installedNames);
    }
  }

  /// Alias — cloud sync no longer enqueues install confirms.
  static Future<void> enqueueFromLeanDiff(LeanApplyResult diff) =>
      applyCloudLeanDiff(diff);
}
