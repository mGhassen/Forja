import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/widgets/settings_pack_prompt_pane.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shell/shell_bus.dart';

/// Listens for plugin install prompts (single deep link + batch profile sync).
///
/// Opens the picker in Settings → Forja Packs (right pane) — never a modal.
/// Pack membership is **profile**-scoped. Prompts stay queued until
/// [ShellBus.splashDismissed] so they never cover account, Who's watching,
/// packs onboarding, or boot / profile splash.
class PluginInstallPromptHost extends StatefulWidget {
  const PluginInstallPromptHost({super.key, required this.child});

  final Widget child;

  @override
  State<PluginInstallPromptHost> createState() =>
      _PluginInstallPromptHostState();
}

class _PluginInstallPromptHostState extends State<PluginInstallPromptHost> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ShellBus.pendingPluginInstall.addListener(_onPending);
    ShellBus.pendingPluginInstallQueue.addListener(_onPending);
    ShellBus.pendingPluginBatchInstall.addListener(_onPending);
    ShellBus.splashDismissed.addListener(_onSplashDismissed);
    SettingsPackPromptDrill.current.addListener(_onDrillChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    ShellBus.pendingPluginInstall.removeListener(_onPending);
    ShellBus.pendingPluginInstallQueue.removeListener(_onPending);
    ShellBus.pendingPluginBatchInstall.removeListener(_onPending);
    ShellBus.splashDismissed.removeListener(_onSplashDismissed);
    SettingsPackPromptDrill.current.removeListener(_onDrillChanged);
    super.dispose();
  }

  void _onDrillChanged() {
    if (SettingsPackPromptDrill.isOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _onPending() {
    if (ShellBus.pendingPluginInstall.value == null &&
        ShellBus.pendingPluginInstallQueue.value.isEmpty &&
        ShellBus.pendingPluginBatchInstall.value == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _onSplashDismissed() {
    if (!ShellBus.splashDismissed.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted || _busy || SettingsPackPromptDrill.isOpen) return;
    if (!ShellBus.splashDismissed.value) return;

    final batch = ShellBus.takePendingPluginBatchInstall();
    if (batch != null && batch.candidates.isNotEmpty) {
      _busy = true;
      try {
        ShellBus.openSettings(
          categoryId: SettingsCategoryId.forjaPacks,
          enterDetail: true,
        );
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final refreshed = await _refreshBatch(batch);
        if (!mounted || refreshed == null) return;
        SettingsPackPromptDrill.open(refreshed);
      } finally {
        if (mounted) _busy = false;
      }
      return;
    }

    final prompt = ShellBus.takePendingPluginInstall();
    if (prompt == null) return;
    _busy = true;
    try {
      ShellBus.openSettings(
        categoryId: SettingsCategoryId.forjaPacks,
        enterDetail: true,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final candidate = await _refreshSingle(prompt);
      if (!mounted || candidate == null) return;
      SettingsPackPromptDrill.open(
        PluginBatchInstallPrompt(candidates: [candidate]),
      );
    } finally {
      if (mounted) _busy = false;
    }
  }

  Future<PluginBatchInstallPrompt?> _refreshBatch(
    PluginBatchInstallPrompt batch,
  ) async {
    final packs = await PluginRegistry.instance.listPacksRaw();
    if (!mounted) return null;
    final byUrl = {for (final p in packs) p.sourceUrl.trim(): p};
    final installedUrls = <String>{};
    for (final p in packs) {
      if (p.plugins.isEmpty) continue;
      if (await PluginRegistry.instance.packNeedsDiskInstall(p)) continue;
      installedUrls.add(p.sourceUrl.trim());
    }
    if (!mounted) return null;
    return PluginBatchInstallPrompt(
      candidates: [
        for (final c in batch.candidates)
          PluginInstallCandidate(
            manifestUrl: c.manifestUrl,
            displayName: c.displayName,
            kind: c.kind,
            fromRemoteProfile: c.fromRemoteProfile,
            alreadyInstalled: c.kind == PluginPackPromptKind.uninstall
                ? !byUrl.containsKey(c.manifestUrl.trim())
                : installedUrls.contains(c.manifestUrl.trim()),
          ),
      ],
    );
  }

  Future<PluginInstallCandidate?> _refreshSingle(
    PluginInstallPrompt prompt,
  ) async {
    final packs = await PluginRegistry.instance.listPacksRaw();
    if (!mounted) return null;
    EnginePack? match;
    for (final p in packs) {
      if (p.sourceUrl.trim() == prompt.manifestUrl.trim()) {
        match = p;
        break;
      }
    }
    var already = false;
    if (prompt.kind == PluginPackPromptKind.uninstall) {
      already = match == null;
    } else if (match != null) {
      already = !await PluginRegistry.instance.packNeedsDiskInstall(match);
    }
    if (!mounted) return null;
    return PluginInstallCandidate(
      manifestUrl: prompt.manifestUrl,
      displayName: prompt.displayName,
      kind: prompt.kind,
      fromRemoteProfile: prompt.source == PluginInstallSource.remoteProfile,
      alreadyInstalled: already,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
