import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/official_forjahq_packs.dart';
import 'package:forja/shared/engine/packs/pack_hub_features.dart';
import 'package:forja/shared/engine/packs/plugin_catalog_remote.dart';
import 'package:forja/shared/engine/packs/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/plugin_install_prompt.dart';
import 'package:forja/shared/engine/packs/plugin_registry.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Resolve official packs (admin-published Supabase → baked offline fallback).
Future<List<OfficialForjaHqPack>> resolveOfficialForjaHqPacks() async {
  final remote = await PluginCatalogRemote.fetchPublishedPacks();
  if (remote.isNotEmpty) {
    final out = List<OfficialForjaHqPack>.from(remote);
    out.sort((a, b) {
      final byRec = (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0);
      if (byRec != 0) return byRec;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }
  return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
}

/// Resolve published product bundles; fallback = hardcoded recommended set.
Future<List<PluginProductBundle>> resolvePublishedBundles() async {
  final remote = await PluginCatalogRemote.fetchPublishedBundles();
  if (remote.isNotEmpty) return remote;
  return [
    PluginProductBundle(
      id: 'best-experience',
      name: 'Best experience',
      description:
          'Core ForjaHQ packs for Home, hubs, providers, live sports, and torrent.',
      recommended: true,
      packIds: kOfficialRecommendedPackIds.toList(growable: false),
    ),
  ];
}

/// Preferred recommended / best-experience bundle (first recommended, else first).
Future<PluginProductBundle?> resolveRecommendedBundle() async {
  final bundles = await resolvePublishedBundles();
  if (bundles.isEmpty) return null;
  for (final b in bundles) {
    if (b.recommended) return b;
  }
  return bundles.first;
}

/// Official packs that belong to [bundle], in bundle order.
Future<List<OfficialForjaHqPack>> resolveBundlePacks(
  PluginProductBundle bundle,
) async {
  final all = await resolveOfficialForjaHqPacks();
  final byId = {for (final p in all) p.id: p};
  final out = <OfficialForjaHqPack>[];
  for (final id in bundle.packIds) {
    final hit = byId[id];
    if (hit != null) out.add(hit);
  }
  return out;
}

typedef OfficialPackInstallProgress = void Function({
  required int done,
  required int total,
  required String status,
});

/// Outcome of [promptOfficialForjaHqPackInstall] (Settings — never silent).
enum OfficialPackPromptOutcome {
  /// Single or batch install dialog queued.
  prompted,

  /// Every official pack is already fully installed on disk.
  alreadyInstalled,

  /// Another install/uninstall prompt is already pending.
  busy,
}

/// Build install candidates for official packs that still need a download.
@visibleForTesting
List<PluginInstallCandidate> officialPackCandidatesMissing({
  required List<OfficialForjaHqPack> targets,
  required Set<String> fullyInstalledUrls,
}) {
  final out = <PluginInstallCandidate>[];
  for (final pack in targets) {
    final url = pack.manifestUrl.trim();
    if (url.isEmpty) continue;
    if (fullyInstalledUrls.contains(url)) continue;
    out.add(
      PluginInstallCandidate(
        manifestUrl: url,
        displayName: pack.name,
        description: pack.description,
        tags: pack.tags,
        catalogKind: pack.kind,
        official: true,
        recommended: pack.recommended ||
            kOfficialRecommendedPackIds.contains(pack.id),
      ),
    );
  }
  out.sort((a, b) {
    final byRec = (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0);
    if (byRec != 0) return byRec;
    final an = (a.displayName ?? '').toLowerCase();
    final bn = (b.displayName ?? '').toLowerCase();
    return an.compareTo(bn);
  });
  return out;
}

/// Missing official packs that still need a download on this device.
Future<List<PluginInstallCandidate>> loadMissingOfficialPackCandidates() async {
  final targets = await resolveOfficialForjaHqPacks();
  final installed = await PluginRegistry.instance.listPacksRaw();
  final fullyInstalled = <String>{};
  for (final pack in installed) {
    final url = pack.sourceUrl.trim();
    if (url.isEmpty) continue;
    if (await PluginRegistry.instance.packNeedsDiskInstall(pack)) continue;
    fullyInstalled.add(url);
  }
  return officialPackCandidatesMissing(
    targets: targets,
    fullyInstalledUrls: fullyInstalled,
  );
}

/// Missing packs from a published product bundle.
Future<List<PluginInstallCandidate>> loadMissingBundlePackCandidates(
  PluginProductBundle bundle,
) async {
  final targets = await resolveBundlePacks(bundle);
  final installed = await PluginRegistry.instance.listPacksRaw();
  final fullyInstalled = <String>{};
  for (final pack in installed) {
    final url = pack.sourceUrl.trim();
    if (url.isEmpty) continue;
    if (await PluginRegistry.instance.packNeedsDiskInstall(pack)) continue;
    fullyInstalled.add(url);
  }
  return officialPackCandidatesMissing(
    targets: targets,
    fullyInstalledUrls: fullyInstalled,
  );
}

/// Settings → Official packs: show the checkbox picker; never auto-download all.
Future<OfficialPackPromptOutcome> promptOfficialForjaHqPackInstall() async {
  if (ShellBus.pendingPluginInstallQueue.value.isNotEmpty ||
      ShellBus.pendingPluginBatchInstall.value != null) {
    return OfficialPackPromptOutcome.busy;
  }

  final candidates = await loadMissingOfficialPackCandidates();
  if (candidates.isEmpty) {
    return OfficialPackPromptOutcome.alreadyInstalled;
  }

  ShellBus.pendingPluginBatchInstall.value =
      PluginBatchInstallPrompt(candidates: candidates);
  return OfficialPackPromptOutcome.prompted;
}

/// Settings → install a published product bundle (batch picker).
Future<OfficialPackPromptOutcome> promptBundlePackInstall(
  PluginProductBundle bundle,
) async {
  if (ShellBus.pendingPluginInstallQueue.value.isNotEmpty ||
      ShellBus.pendingPluginBatchInstall.value != null) {
    return OfficialPackPromptOutcome.busy;
  }

  final candidates = await loadMissingBundlePackCandidates(bundle);
  if (candidates.isEmpty) {
    return OfficialPackPromptOutcome.alreadyInstalled;
  }

  ShellBus.pendingPluginBatchInstall.value =
      PluginBatchInstallPrompt(candidates: candidates);
  return OfficialPackPromptOutcome.prompted;
}

/// Prompt install for the recommended / best-experience bundle.
Future<OfficialPackPromptOutcome> promptRecommendedBundleInstall() async {
  final bundle = await resolveRecommendedBundle();
  if (bundle == null) {
    return promptOfficialForjaHqPackInstall();
  }
  return promptBundlePackInstall(bundle);
}

/// Sequential install of the given official candidates. Returns failed names.
Future<List<String>> installSelectedOfficialPacks(
  List<PluginInstallCandidate> selected, {
  OfficialPackInstallProgress? onProgress,
}) async {
  final todo = selected
      .where((c) =>
          c.kind == PluginPackPromptKind.install &&
          !c.alreadyInstalled &&
          c.manifestUrl.trim().isNotEmpty)
      .toList(growable: false);
  if (todo.isEmpty) {
    onProgress?.call(done: 0, total: 0, status: 'Nothing to install');
    return const [];
  }

  final failures = <String>[];
  final installed = <EnginePack>[];
  for (var i = 0; i < todo.length; i++) {
    final pack = todo[i];
    final label = pack.displayName?.trim().isNotEmpty == true
        ? pack.displayName!.trim()
        : pack.manifestUrl.trim();
    onProgress?.call(
      done: i,
      total: todo.length,
      status: 'Installing $label (${i + 1}/${todo.length})…',
    );
    try {
      final enginePack = await PluginInstallCoordinator.instance
          .installManifest(pack.manifestUrl.trim());
      installed.add(enginePack);
    } catch (e) {
      debugPrint('[OfficialPacks] install $label failed: $e');
      failures.add(label);
    }
  }
  // Destinations first, then RFC-086 default-on Features/rail (same as pack ON).
  if (installed.isNotEmpty) {
    onProgress?.call(
      done: todo.length,
      total: todo.length,
      status: 'Activating Features…',
    );
    await PackHubFeatures.refreshAndActivateInstalled(installed);
  }
  onProgress?.call(
    done: todo.length,
    total: todo.length,
    status: failures.isEmpty ? 'Ready' : 'Finished with errors',
  );
  return failures;
}

/// Sequential install of every missing official pack. Returns failed pack names.
Future<List<String>> installOfficialForjaHqPacks({
  OfficialPackInstallProgress? onProgress,
}) async {
  final candidates = await loadMissingOfficialPackCandidates();
  return installSelectedOfficialPacks(candidates, onProgress: onProgress);
}

/// Install missing packs from the recommended product bundle (ordered).
Future<List<String>> installRecommendedBundlePacks({
  OfficialPackInstallProgress? onProgress,
}) async {
  final bundle = await resolveRecommendedBundle();
  if (bundle == null) {
    return installOfficialForjaHqPacks(onProgress: onProgress);
  }
  final candidates = await loadMissingBundlePackCandidates(bundle);
  return installSelectedOfficialPacks(candidates, onProgress: onProgress);
}
