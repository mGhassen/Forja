import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/sync/src/sync_service.dart';

/// Progress for the in-shell install banner / splash status line.
class PluginInstallProgress {
  const PluginInstallProgress({
    required this.label,
    required this.completedSteps,
    required this.totalSteps,
    required this.isUpdate,
  });

  final String label;
  final int completedSteps;
  final int totalSteps;
  final bool isUpdate;

  double get fraction {
    if (totalSteps <= 0) return 0;
    return (completedSteps / totalSteps).clamp(0.0, 1.0);
  }
}

/// Boot + background: migrate, await cloud lean, install missing / updates.
class PluginInstallCoordinator {
  PluginInstallCoordinator._();
  static final PluginInstallCoordinator instance = PluginInstallCoordinator._();

  final ValueNotifier<PluginInstallProgress?> progress =
      ValueNotifier<PluginInstallProgress?>(null);

  /// When true, [PluginInstallProgressBannerHost] stays hidden — splash /
  /// profile warm own the bottom status text instead of a card.
  final ValueNotifier<bool> suppressBanner = ValueNotifier<bool>(false);

  Future<void>? _inFlight;

  Future<void> ensureAllInstalled({
    bool checkUpdates = true,
    bool awaitCloudLean = true,
    bool includeNuvio = true,
  }) {
    return _inFlight ??= _run(
      checkUpdates: checkUpdates,
      awaitCloudLean: awaitCloudLean,
      includeNuvio: includeNuvio,
    ).whenComplete(() {
      _inFlight = null;
      progress.value = null;
    });
  }

  Future<void> _run({
    required bool checkUpdates,
    required bool awaitCloudLean,
    required bool includeNuvio,
  }) async {
    final registry = PluginRegistry.instance;

    await registry.migrateScriptsToDiskIfNeeded();
    await NuvioService.instance.migrateScriptsToDiskIfNeeded();

    if (awaitCloudLean && SyncService.instance.isSignedIn) {
      _setProgress(
        const PluginInstallProgress(
          label: 'Syncing plugins…',
          completedSteps: 0,
          totalSteps: 1,
          isUpdate: false,
        ),
      );
      try {
        await SyncDomainBridge.instance.syncFromCloud();
      } catch (e) {
        debugPrint('[PluginInstall] cloud sync failed (non-fatal): $e');
      }
    }

    await registry.migrateLegacyLiveSportPacksIfNeeded();

    final packs = await registry.listPacksRaw();
    final jobs = <({EnginePack pack, bool isUpdate})>[];

    for (final pack in packs) {
      if (PluginRegistry.isLegacyAssetPack(pack.sourceUrl)) continue;
      if (PluginRegistry.isLocalManifestUrl(pack.sourceUrl)) continue;
      if (PluginRegistry.isRetiredCatalogPack(pack)) continue;
      if (await registry.packNeedsDiskInstall(pack)) {
        jobs.add((pack: pack, isUpdate: false));
        continue;
      }
      if (checkUpdates && pack.plugins.isNotEmpty) {
        jobs.add((pack: pack, isUpdate: true));
      }
    }

    // Updates are checked inside the loop; missing installs always run.
    var completed = 0;
    final total = jobs.length + (includeNuvio ? 1 : 0);
    if (total == 0) return;

    for (final job in jobs) {
      final pack = job.pack;
      if (job.isUpdate) {
        _setProgress(
          PluginInstallProgress(
            label: 'Checking ${pack.name}…',
            completedSteps: completed,
            totalSteps: total,
            isUpdate: true,
          ),
        );
        final updated = await registry.maybeRefreshIfNewer(
          pack.sourceUrl,
          pack,
        );
        if (updated) {
          _setProgress(
            PluginInstallProgress(
              label: 'Updated ${pack.name}',
              completedSteps: completed + 1,
              totalSteps: total,
              isUpdate: true,
            ),
          );
        }
      } else {
        _setProgress(
          PluginInstallProgress(
            label: 'Installing ${pack.name}…',
            completedSteps: completed,
            totalSteps: total,
            isUpdate: false,
          ),
        );
        try {
          await registry.install(
            pack.sourceUrl,
            onScriptFetched: () {
              // Soft tick — pack-level progress stays primary.
            },
          );
        } catch (e) {
          debugPrint(
            '[PluginInstall] install failed (${pack.sourceUrl}): $e',
          );
          PluginRegistry.officialInstallError.value =
              e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        }
      }
      completed++;
      _setProgress(
        PluginInstallProgress(
          label: job.isUpdate
              ? 'Checked ${pack.name}'
              : 'Installed ${pack.name}',
          completedSteps: completed,
          totalSteps: total,
          isUpdate: job.isUpdate,
        ),
      );
    }

    if (includeNuvio) {
      _setProgress(
        PluginInstallProgress(
          label: 'Installing Nuvio scrapers…',
          completedSteps: completed,
          totalSteps: total,
          isUpdate: false,
        ),
      );
      try {
        await NuvioService.instance.ensureBundledInstalled();
        await NuvioService.instance.hydrateLeanInstalled();
        await NuvioService.instance.ensureScriptsOnDisk();
      } catch (e) {
        debugPrint('[PluginInstall] nuvio hydrate failed: $e');
      }
      completed++;
      _setProgress(
        PluginInstallProgress(
          label: 'Plugins ready',
          completedSteps: completed,
          totalSteps: total,
          isUpdate: false,
        ),
      );
    }

    if (PluginRegistry.officialInstallError.value == null) {
      // clear via registry helper path on successful installs
    }
  }

  void _setProgress(PluginInstallProgress? value) {
    progress.value = value;
  }
}
