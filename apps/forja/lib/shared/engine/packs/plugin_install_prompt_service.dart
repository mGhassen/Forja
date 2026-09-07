import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/lean_apply_result.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/plugin_registry.dart';
import 'package:forja/shared/engine/packs/remote_pack_intent_store.dart';

/// Apply a cloud lean diff on this device: auto-install adds, toast results.
///
/// Removals are already purged by [PluginRegistry.applyLeanManifestUrls] when
/// `purgeRemovedImmediately` is true. Boot warm skips here — splash
/// [PluginInstallCoordinator.ensureAllInstalled] hydrates membership.
abstract final class PluginInstallPromptService {
  /// Mid-session cloud sync: download new packs; toast installs + removals.
  static Future<void> applyCloudLeanDiff(LeanApplyResult diff) async {
    if (diff.isEmpty) return;
    if (PluginInstallCoordinator.instance.isBootWarm) return;

    final coordinator = PluginInstallCoordinator.instance;
    final registry = PluginRegistry.instance;

    if (diff.removed.isNotEmpty) {
      final labeled = [
        for (final row in diff.removed)
          (row.name?.trim().isNotEmpty == true) ? row.name!.trim() : 'Pack',
      ];
      await coordinator.notifyCloudPacksRemoved(labeled);
    }

    final installedNames = <String>[];
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
        installedNames.add(
          label?.isNotEmpty == true ? label! : pack.name,
        );
      } catch (e) {
        debugPrint('[PluginInstall] cloud auto-install failed ($url): $e');
      }
    }

    if (installedNames.isNotEmpty) {
      await coordinator.notifyCloudPacksInstalled(installedNames);
    }
  }

  /// Alias — cloud sync no longer enqueues install confirms.
  static Future<void> enqueueFromLeanDiff(LeanApplyResult diff) =>
      applyCloudLeanDiff(diff);
}
