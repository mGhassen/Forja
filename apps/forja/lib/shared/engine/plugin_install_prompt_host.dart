import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/plugin_batch_install_prompt_dialog.dart';
import 'package:forja/shared/engine/plugin_install_prompt_dialog.dart';
import 'package:forja/shell/shell_bus.dart';

/// Listens for plugin install prompts (single deep link + batch profile sync).
///
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
  PluginInstallPrompt? _prompt;
  PluginBatchInstallPrompt? _batchPrompt;
  bool _alreadyInstalled = false;

  @override
  void initState() {
    super.initState();
    ShellBus.pendingPluginInstall.addListener(_onPending);
    ShellBus.pendingPluginInstallQueue.addListener(_onPending);
    ShellBus.pendingPluginBatchInstall.addListener(_onPending);
    ShellBus.splashDismissed.addListener(_onSplashDismissed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    ShellBus.pendingPluginInstall.removeListener(_onPending);
    ShellBus.pendingPluginInstallQueue.removeListener(_onPending);
    ShellBus.pendingPluginBatchInstall.removeListener(_onPending);
    ShellBus.splashDismissed.removeListener(_onSplashDismissed);
    super.dispose();
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
    if (!mounted || _busy || _prompt != null || _batchPrompt != null) return;
    // Keep queued until a profile is active and splash chrome is gone.
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
        final packs = await PluginRegistry.instance.listPacksRaw();
        if (!mounted) return;
        final byUrl = {for (final p in packs) p.sourceUrl.trim(): p};
        final installedUrls = <String>{};
        for (final p in packs) {
          if (p.plugins.isEmpty) continue;
          if (await PluginRegistry.instance.packNeedsDiskInstall(p)) continue;
          installedUrls.add(p.sourceUrl.trim());
        }
        if (!mounted) return;
        final refreshed = PluginBatchInstallPrompt(
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
        setState(() => _batchPrompt = refreshed);
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
      final packs = await PluginRegistry.instance.listPacksRaw();
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _prompt = prompt;
        _alreadyInstalled = already;
      });
    } finally {
      if (mounted) _busy = false;
    }
  }

  void _dismissSingle() {
    if (_prompt == null) return;
    setState(() {
      _prompt = null;
      _alreadyInstalled = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _dismissBatch() {
    if (_batchPrompt == null) return;
    setState(() => _batchPrompt = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _prompt;
    final batch = _batchPrompt;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (batch != null)
          PluginBatchInstallPromptOverlay(
            prompt: batch,
            onDismiss: _dismissBatch,
          ),
        if (prompt != null)
          PluginInstallPromptOverlay(
            prompt: prompt,
            alreadyInstalled: _alreadyInstalled,
            onDismiss: _dismissSingle,
          ),
      ],
    );
  }
}
