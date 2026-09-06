import 'package:forja/shared/engine/lean_apply_result.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';
import 'package:forja/shell/shell_bus.dart';

/// Enqueue mid-session install/uninstall confirms from a cloud lean diff.
///
/// Remote-profile changes always land as **one** [PluginBatchInstallPrompt]
/// (install + uninstall rows together) — never pack-by-pack FIFO.
abstract final class PluginInstallPromptService {
  static Future<void> enqueueFromLeanDiff(LeanApplyResult diff) async {
    if (diff.isEmpty) return;
    if (PluginInstallCoordinator.instance.isBootWarm) return;

    final registry = PluginRegistry.instance;
    final packs = await registry.listPacksRaw();
    final byUrl = {for (final p in packs) p.sourceUrl: p};

    final candidates = <PluginInstallCandidate>[];

    for (final row in diff.added) {
      final url = row.manifestUrl.trim();
      if (url.isEmpty) continue;
      if (await DeferredRemoteInstallStore.contains(url)) continue;
      final local = byUrl[url];
      if (local != null && !await registry.packNeedsDiskInstall(local)) {
        continue;
      }
      candidates.add(
        PluginInstallCandidate(
          manifestUrl: url,
          displayName: row.name ?? local?.name,
          kind: PluginPackPromptKind.install,
          fromRemoteProfile: true,
        ),
      );
    }

    for (final row in diff.removed) {
      final url = row.manifestUrl.trim();
      if (url.isEmpty) continue;
      if (await PendingRemotePurgeStore.contains(url)) continue;
      final local = byUrl[url];
      if (local == null) continue;
      candidates.add(
        PluginInstallCandidate(
          manifestUrl: url,
          displayName: row.name ?? local.name,
          kind: PluginPackPromptKind.uninstall,
          fromRemoteProfile: true,
        ),
      );
    }

    if (candidates.isEmpty) return;
    _mergeBatch(candidates);
  }

  /// Coalesce into [ShellBus.pendingPluginBatchInstall] (dedupe by kind+url).
  static void _mergeBatch(List<PluginInstallCandidate> incoming) {
    final existing = ShellBus.pendingPluginBatchInstall.value;
    final merged = <PluginInstallCandidate>[];
    final seen = <String>{};

    void add(PluginInstallCandidate c) {
      final url = c.manifestUrl.trim();
      if (url.isEmpty) return;
      final key = '${c.kind.name}|$url';
      if (!seen.add(key)) return;
      merged.add(
        PluginInstallCandidate(
          manifestUrl: url,
          displayName: c.displayName,
          description: c.description,
          tags: c.tags,
          catalogKind: c.catalogKind,
          version: c.version,
          official: c.official,
          recommended: c.recommended,
          alreadyInstalled: c.alreadyInstalled,
          kind: c.kind,
          fromRemoteProfile: c.fromRemoteProfile,
        ),
      );
    }

    if (existing != null) {
      for (final c in existing.candidates) {
        add(c);
      }
    }
    for (final c in incoming) {
      add(c);
    }

    ShellBus.pendingPluginBatchInstall.value =
        PluginBatchInstallPrompt(candidates: merged);
  }
}
