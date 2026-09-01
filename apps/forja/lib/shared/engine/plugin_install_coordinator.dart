import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shared/playback/torrent_js_search.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/sync/src/sync_service.dart';

/// User-visible install phase for Settings + shell banner.
enum PluginInstallPhase { loading, installing, ready }

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
  final String? sourceUrl;
  final String? manifestUrl;

  double get fraction {
    if (totalSteps <= 0) return 0;
    return (completedSteps / totalSteps).clamp(0.0, 1.0);
  }

  PluginInstallPhase get phase {
    final lower = label.toLowerCase();
    if (lower.startsWith('ready') || lower.contains('plugins ready')) {
      return PluginInstallPhase.ready;
    }
    if (lower.startsWith('fetching') ||
        lower.startsWith('syncing') ||
        lower.startsWith('checking') ||
        (completedSteps == 0 && fraction <= 0)) {
      return PluginInstallPhase.loading;
    }
    if (fraction >= 1.0) return PluginInstallPhase.ready;
    return PluginInstallPhase.installing;
  }

  String get phaseTitle => switch (phase) {
        PluginInstallPhase.loading => 'Loading',
        PluginInstallPhase.installing => 'Installing',
        PluginInstallPhase.ready => 'Ready',
      };

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

  /// How long the bottom banner stays on "Ready" before dismissing.
  static const readyDwell = Duration(milliseconds: 2200);

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
    return _manualInstall ??= _installManifestSingle(url, isUpdate: isUpdate)
        .whenComplete(() => _manualInstall = null);
  }

  Future<EnginePack> _installManifestSingle(
    String manifestUrl, {
    required bool isUpdate,
  }) async {
    try {
      final pack = await _fetchPackWithProgress(
        manifestUrl: manifestUrl,
        isUpdate: isUpdate,
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
      await Future<void>.delayed(readyDwell);
      return pack;
    } finally {
      progress.value = null;
    }
  }

  /// Auto-refresh before catalog use — shows progress, no manual Reload.
  Future<bool> ensurePluginReady(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return false;
    if (_inFlight != null) await _inFlight;
    if (_manualInstall != null) await _manualInstall;

    final hit = PluginRegistry.packPluginFromPacks(
      await PluginRegistry.instance.listPacksRaw(),
      want,
    );
    if (hit == null) return false;

    final url = hit.pack.sourceUrl;
    final local = PluginRegistry.isLocalManifestUrl(url);
    final needsDisk = await PluginRegistry.instance.packNeedsDiskInstall(hit.pack);

    // Bundled checkout (plugins/iptv/vod, plugins/hubs/*, …): JS is read from
    // disk on each run — do not re-fetch manifest + show "Updating…" per tap.
    if (local) {
      return PluginRegistry.instance.ensurePackScriptsReady(hit.pack);
    }
    if (!needsDisk) return true;

    try {
      await _installManifestSingle(url, isUpdate: false);
      return true;
    } catch (e) {
      debugPrint('[PluginInstall] ensurePluginReady($want) failed: $e');
      return false;
    }
  }

  Future<EnginePack> _fetchPackWithProgress({
    required String manifestUrl,
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
    return EngineService.instance.installWithProgress(
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
  }

  /// User-facing copy when a catalog plugin is invoked before scripts land.
  Future<String?> pluginNotReadyMessage(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return null;
    final current = progress.value;
    if (current != null) {
      return '${current.phaseTitle} ${current.label} — wait for the progress banner at the bottom.';
    }
    final hit = PluginRegistry.packPluginFromPacks(
      await PluginRegistry.instance.listPacksRaw(),
      want,
    );
    if (hit == null) {
      return 'Plugin not installed. Add its manifest in Settings → Forja plugins.';
    }
    if (await PluginRegistry.instance.packNeedsDiskInstall(hit.pack)) {
      return '${hit.pack.name} is still downloading. '
          'Open Settings → Forja plugins to watch progress.';
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
    final jobs = <({EnginePack pack, bool isUpdate, bool forceRefresh})>[];

    for (final pack in packs) {
      if (PluginRegistry.isLegacyAssetPack(pack.sourceUrl)) continue;
      if (PluginRegistry.isRetiredCatalogPack(pack)) continue;
      if (await registry.packNeedsDiskInstall(pack)) {
        jobs.add((pack: pack, isUpdate: false, forceRefresh: true));
        continue;
      }
      if (!checkUpdates) continue;
      final local = PluginRegistry.isLocalManifestUrl(pack.sourceUrl);
      jobs.add((pack: pack, isUpdate: true, forceRefresh: local));
    }

    var completed = 0;
    final total = jobs.length + (includeNuvio ? 1 : 0);
    debugPrint(
      '[PluginInstall] ${jobs.length} pack job(s), '
      'nuvio=${includeNuvio ? 1 : 0}',
    );
    if (total == 0) return;

    for (final job in jobs) {
      final pack = job.pack;
      final url = pack.sourceUrl;
      try {
        if (job.forceRefresh) {
          await _fetchPackWithProgress(
            manifestUrl: url,
            isUpdate: job.isUpdate,
          );
        } else {
          _setProgress(
            PluginInstallProgress(
              label: 'Checking ${pack.name}…',
              manifestUrl: url,
              sourceUrl: url,
              completedSteps: completed,
              totalSteps: total,
              isUpdate: true,
            ),
          );
          final updated = await registry.maybeRefreshIfNewer(url, pack);
          if (updated) {
            debugPrint('[PluginInstall] updated ${pack.name}');
          }
        }
      } catch (e) {
        debugPrint('[PluginInstall] install failed ($url): $e');
        PluginRegistry.officialInstallError.value =
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      }
      completed++;
      _setProgress(
        PluginInstallProgress(
          label: job.isUpdate ? 'Ready — ${pack.name}' : 'Installed ${pack.name}',
          manifestUrl: url,
          sourceUrl: url,
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
    }

    _setProgress(
      PluginInstallProgress(
        label: 'Ready — all plugins',
        completedSteps: total,
        totalSteps: total,
        isUpdate: false,
      ),
    );
    await syncTorrentSearchCatalog();
    await Future<void>.delayed(readyDwell);
  }

  void _setProgress(PluginInstallProgress? value) {
    progress.value = value;
  }
}
