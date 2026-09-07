import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/official_forjahq_packs.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:http/http.dart' as http;

/// Resolve official ForjaHQ packs (catalog filter + baked URL fallback).
Future<List<OfficialForjaHqPack>> resolveOfficialForjaHqPacks() async {
  final byId = {
    for (final p in kOfficialForjaHqPacks) p.id: p,
  };
  try {
    final res = await http
        .get(Uri.parse(kPluginCatalogUrl))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
    }
    final packs = decoded['packs'];
    if (packs is! List) {
      return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
    }
    final out = <OfficialForjaHqPack>[];
    for (final raw in packs) {
      if (raw is! Map) continue;
      if (raw['official'] != true) continue;
      final id = (raw['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;
      final baked = byId[id];
      if (baked == null) continue;
      final name = (raw['name'] as String?)?.trim();
      final desc = (raw['description'] as String?)?.trim();
      final kind = (raw['kind'] as String?)?.trim();
      final tagsRaw = raw['tags'];
      final tags = <String>[
        if (tagsRaw is List)
          for (final t in tagsRaw)
            if (t is String && t.trim().isNotEmpty) t.trim(),
      ];
      final recommended = raw['recommended'] == true ||
          baked.recommended ||
          kOfficialRecommendedPackIds.contains(id);
      out.add(
        OfficialForjaHqPack(
          id: baked.id,
          name: (name != null && name.isNotEmpty) ? name : baked.name,
          description: (desc != null && desc.isNotEmpty)
              ? desc
              : baked.description,
          kind: (kind != null && kind.isNotEmpty) ? kind : baked.kind,
          tags: tags.isNotEmpty ? tags : baked.tags,
          recommended: recommended,
          manifestUrl: baked.manifestUrl,
        ),
      );
    }
    if (out.isNotEmpty) {
      out.sort((a, b) {
        final byRec = (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0);
        if (byRec != 0) return byRec;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return out;
    }
  } catch (e) {
    debugPrint('[OfficialPacks] catalog fetch failed: $e');
  }
  return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
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

/// Settings → Official packs: show the checkbox picker; never auto-download all.
Future<OfficialPackPromptOutcome> promptOfficialForjaHqPackInstall() async {
  if (ShellBus.pendingPluginInstallQueue.value.isNotEmpty ||
      ShellBus.pendingPluginBatchInstall.value != null) {
    return OfficialPackPromptOutcome.busy;
  }

  final targets = await resolveOfficialForjaHqPacks();
  final installed = await PluginRegistry.instance.listPacksRaw();
  final fullyInstalled = <String>{};
  for (final pack in installed) {
    final url = pack.sourceUrl.trim();
    if (url.isEmpty) continue;
    if (await PluginRegistry.instance.packNeedsDiskInstall(pack)) continue;
    fullyInstalled.add(url);
  }

  final candidates = officialPackCandidatesMissing(
    targets: targets,
    fullyInstalledUrls: fullyInstalled,
  );
  if (candidates.isEmpty) {
    return OfficialPackPromptOutcome.alreadyInstalled;
  }

  // Always batch (even one pack) so Settings shows the right-pane picker.
  ShellBus.pendingPluginBatchInstall.value =
      PluginBatchInstallPrompt(candidates: candidates);
  return OfficialPackPromptOutcome.prompted;
}

/// Sequential install of missing official packs. Returns failed pack names.
///
/// Used by packs onboarding (explicit “install the bundle” CTA). Settings uses
/// [promptOfficialForjaHqPackInstall] instead.
Future<List<String>> installOfficialForjaHqPacks({
  OfficialPackInstallProgress? onProgress,
}) async {
  final targets = await resolveOfficialForjaHqPacks();
  final installed = await PluginRegistry.instance.listPacksRaw();
  final have = {
    for (final p in installed) p.sourceUrl.trim(),
  };
  final todo = targets
      .where((p) => !have.contains(p.manifestUrl.trim()))
      .toList(growable: false);

  if (todo.isEmpty) {
    onProgress?.call(done: 0, total: 0, status: 'All official packs installed');
    return const [];
  }

  final failures = <String>[];
  for (var i = 0; i < todo.length; i++) {
    final pack = todo[i];
    onProgress?.call(
      done: i,
      total: todo.length,
      status: 'Installing ${pack.name} (${i + 1}/${todo.length})…',
    );
    try {
      await PluginInstallCoordinator.instance.installManifest(pack.manifestUrl);
    } catch (e) {
      debugPrint('[OfficialPacks] install ${pack.id} failed: $e');
      failures.add(pack.name);
    }
  }
  onProgress?.call(
    done: todo.length,
    total: todo.length,
    status: failures.isEmpty ? 'Ready' : 'Finished with errors',
  );
  return failures;
}
