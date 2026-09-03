import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shared/playback/torrent_js_search.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:forja/shell/shell_bus.dart';

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

/// Boot + background: migrate, await cloud lean, install missing scripts only.
/// Version bumps are never auto-installed — user updates in Settings.
class PluginInstallCoordinator {
  PluginInstallCoordinator._();
  static final PluginInstallCoordinator instance = PluginInstallCoordinator._();

  /// How long the bottom banner stays on "Ready" before dismissing.
  static const readyDwell = Duration(milliseconds: 2200);

  static bool _updateToastShownThisSession = false;

  /// Toast → Update: packs to confirm in [PluginPackUpdatePromptHost].
  final ValueNotifier<List<EnginePackUpdateInfo>?> pendingUpdatePrompt =
      ValueNotifier<List<EnginePackUpdateInfo>?>(null);

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
      return 'Plugin not installed. Add its manifest in Settings → Forja Packs.';
    }
    if (await PluginRegistry.instance.packNeedsDiskInstall(hit.pack)) {
      return '${hit.pack.name} is still downloading. '
          'Open Settings → Forja Packs to watch progress.';
    }
    return null;
  }

  /// Peek remote manifests; toast once per session when updates exist.
  Future<void> notifyPendingUpdatesIfAny() async {
    try {
      final packs = await PluginRegistry.instance.listPacksRaw();
      final updates = await EngineService.instance.checkPackUpdates(packs);
      if (updates.isEmpty) return;
      if (_updateToastShownThisSession) return;
      _updateToastShownThisSession = true;
      final list = updates.values.toList(growable: false);
      final count = list.length;
      final sample = list.first.packName;
      ForjaToast.info(
        count == 1
            ? '$sample update available'
            : '$count plugin updates available',
        duration: const Duration(seconds: 8),
        actionLabel: 'Update',
        onAction: () {
          pendingUpdatePrompt.value = list;
        },
      );
    } catch (e) {
      debugPrint('[PluginInstall] update notify failed: $e');
    }
  }

  /// Consume the toast-driven update confirm payload (host shows dialog).
  List<EnginePackUpdateInfo>? takePendingUpdatePrompt() {
    final value = pendingUpdatePrompt.value;
    pendingUpdatePrompt.value = null;
    return value;
  }

  /// Install every pending pack update; returns how many succeeded.
  Future<int> updatePacks(List<EnginePackUpdateInfo> updates) async {
    if (updates.isEmpty) return 0;
    var ok = 0;
    for (final entry in updates) {
      try {
        await installManifest(entry.sourceUrl, isUpdate: true);
        ok++;
      } catch (e) {
        debugPrint(
          '[PluginInstall] update failed (${entry.sourceUrl}): $e',
        );
        ForjaToast.error('${entry.packName} update failed: $e');
      }
    }
    return ok;
  }

  @visibleForTesting
  static void resetUpdateToastForTest() {
    _updateToastShownThisSession = false;
  }

  Future<void> ensureAllInstalled({
    bool notifyUpdates = true,
    bool awaitCloudLean = false,
    bool includeNuvio = true,
  }) {
    return _inFlight ??= _run(
      notifyUpdates: notifyUpdates,
      awaitCloudLean: awaitCloudLean,
      includeNuvio: includeNuvio,
    ).whenComplete(() {
      _inFlight = null;
      progress.value = null;
    });
  }

  Future<void> _run({
    required bool notifyUpdates,
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
      if (await registry.packNeedsDiskInstall(pack)) {
        jobs.add((pack: pack, isUpdate: false, forceRefresh: true));
      }
    }

    if (jobs.length >= 2) {
      final prompt = await buildBatchInstallPrompt();
      final pending =
          prompt?.candidates.where((c) => !c.alreadyInstalled).length ?? 0;
      if (pending >= 2) {
        ShellBus.pendingPluginBatchInstall.value = prompt;
        jobs.clear();
        debugPrint(
          '[PluginInstall] deferred $pending pack(s) — batch prompt',
        );
      }
    }

    var completed = 0;
    final total = jobs.length + (includeNuvio ? 1 : 0);
    debugPrint(
      '[PluginInstall] ${jobs.length} pack job(s), '
      'nuvio=${includeNuvio ? 1 : 0}',
    );

    for (final job in jobs) {
      final pack = job.pack;
      final url = pack.sourceUrl;
      try {
        await _fetchPackWithProgress(
          manifestUrl: url,
          isUpdate: job.isUpdate,
        );
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

    if (total > 0) {
      _setProgress(
        PluginInstallProgress(
          label: 'Ready — all plugins',
          completedSteps: total,
          totalSteps: total,
          isUpdate: false,
        ),
      );
      await Future<void>.delayed(readyDwell);
    }

    await syncTorrentSearchCatalog();
    if (notifyUpdates) {
      unawaited(notifyPendingUpdatesIfAny());
    }
  }

  /// Build a batch picker from profile pack rows (installed + pending disk).
  Future<PluginBatchInstallPrompt?> buildBatchInstallPrompt() async {
    final registry = PluginRegistry.instance;
    final packs = await registry.listPacksRaw();
    final candidates = <PluginInstallCandidate>[];
    for (final pack in packs) {
      if (PluginRegistry.isLegacyAssetPack(pack.sourceUrl)) continue;
      final needs = await registry.packNeedsDiskInstall(pack);
      candidates.add(
        PluginInstallCandidate(
          manifestUrl: pack.sourceUrl,
          displayName: pack.name,
          alreadyInstalled: !needs,
        ),
      );
    }
    if (candidates.isEmpty) return null;
    return PluginBatchInstallPrompt(candidates: candidates);
  }

  /// Open the global batch install picker (empty-state CTA, manual retry).
  Future<void> requestBatchInstallPrompt() async {
    final prompt = await buildBatchInstallPrompt();
    if (prompt == null) return;
    ShellBus.pendingPluginBatchInstall.value = prompt;
  }

  void _setProgress(PluginInstallProgress? value) {
    progress.value = value;
  }
}
