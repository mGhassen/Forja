import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/service.dart';
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
    this.sourceUrl,
    this.manifestUrl,
  });

  final String label;
  final int completedSteps;
  final int totalSteps;
  final bool isUpdate;

  /// Pack [sourceUrl] when a single manifest is installing (Settings add).
  final String? sourceUrl;

  /// Human-readable manifest URL shown in Settings while downloading.
  final String? manifestUrl;

  double get fraction {
    if (totalSteps <= 0) return 0;
    return (completedSteps / totalSteps).clamp(0.0, 1.0);
  }

  bool matchesUrl(String url) {
    final want = url.trim();
    if (want.isEmpty) return false;
    return sourceUrl == want || manifestUrl == want;
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
  Future<EnginePack>? _manualInstall;

  bool get isInstalling => progress.value != null;

  bool isInstallingUrl(String url) => progress.value?.matchesUrl(url) ?? false;

  /// Settings → Add plugin (or refresh one pack) with visible download progress.
  Future<EnginePack> installManifest(
    String manifestUrl, {
    bool isUpdate = false,
  }) {
    final url = manifestUrl.trim();
    if (url.isEmpty) {
      return Future.error(ArgumentError('manifest URL is empty'));
    }
    return _manualInstall ??= _installManifestImpl(url, isUpdate: isUpdate)
        .whenComplete(() => _manualInstall = null);
  }

  Future<EnginePack> _installManifestImpl(
    String manifestUrl, {
    required bool isUpdate,
  }) async {
    _setProgress(
      PluginInstallProgress(
        label: 'Fetching manifest…',
        manifestUrl: manifestUrl,
        sourceUrl: manifestUrl,
        completedSteps: 0,
        totalSteps: 1,
        isUpdate: isUpdate,
      ),
    );
    try {
      final pack = await EngineService.instance.installWithProgress(
        manifestUrl,
        onFetchProgress: (tick) {
          _setProgress(
            PluginInstallProgress(
              label: tick.label,
              manifestUrl: manifestUrl,
              sourceUrl: manifestUrl,
              completedSteps: tick.completed,
              totalSteps: tick.total,
              isUpdate: isUpdate,
            ),
          );
        },
      );
      _setProgress(
        PluginInstallProgress(
          label: 'Ready — ${pack.name}',
          manifestUrl: manifestUrl,
          sourceUrl: manifestUrl,
          completedSteps: 1,
          totalSteps: 1,
          isUpdate: isUpdate,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return pack;
    } finally {
      progress.value = null;
    }
  }

  /// User-facing copy when a catalog plugin is invoked before scripts land.
  Future<String?> pluginNotReadyMessage(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return null;
    final current = progress.value;
    if (current != null) {
      return 'Still downloading ${current.label}. '
          'Wait for the progress bar to finish or open Settings → Forja plugins.';
    }
    final hit = PluginRegistry.packPluginFromPacks(
      await PluginRegistry.instance.listPacksRaw(),
      want,
    );
    if (hit == null) {
      return 'Plugin not installed. Add its manifest in Settings → Forja plugins.';
    }
    if (await PluginRegistry.instance.packNeedsDiskInstall(hit.pack)) {
      return '${hit.pack.name} is registered but scripts are not on this device yet. '
          'Open Settings → Forja plugins and wait for the download to finish.';
    }
    return null;
  }

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
      if (PluginRegistry.isRetiredCatalogPack(pack)) continue;
      // Remote lean / missing disk JS.
      if (await registry.packNeedsDiskInstall(pack)) {
        jobs.add((pack: pack, isUpdate: false));
        continue;
      }
      // Remote + local checkout: re-read manifest; install when version is newer.
      // (Local packs were previously skipped — Settings showed stale versions until
      // manual Reload.)
      if (checkUpdates) {
        jobs.add((pack: pack, isUpdate: true));
      }
    }

    // Updates are checked inside the loop; missing installs always run.
    var completed = 0;
    final total = jobs.length + (includeNuvio ? 1 : 0);
    debugPrint(
      '[PluginInstall] ${jobs.length} pack job(s), '
      'nuvio=${includeNuvio ? 1 : 0}',
    );
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
          debugPrint('[PluginInstall] updated ${pack.name}');
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
