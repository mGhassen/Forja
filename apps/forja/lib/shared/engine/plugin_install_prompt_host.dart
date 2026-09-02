import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_install_prompt_dialog.dart';
import 'package:forja/shell/shell_bus.dart';

/// Listens for [ShellBus.pendingPluginInstall] and shows the confirm overlay app-wide.
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
  bool _alreadyInstalled = false;

  @override
  void initState() {
    super.initState();
    ShellBus.pendingPluginInstall.addListener(_onPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    ShellBus.pendingPluginInstall.removeListener(_onPending);
    super.dispose();
  }

  void _onPending() {
    if (ShellBus.pendingPluginInstall.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted || _busy || _prompt != null) return;
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
      final already = packs.any(
        (p) => p.sourceUrl.trim() == prompt.manifestUrl.trim(),
      );
      setState(() {
        _prompt = prompt;
        _alreadyInstalled = already;
      });
    } finally {
      if (mounted) _busy = false;
    }
  }

  void _dismiss() {
    if (_prompt == null) return;
    setState(() {
      _prompt = null;
      _alreadyInstalled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _prompt;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (prompt != null)
          PluginInstallPromptOverlay(
            prompt: prompt,
            alreadyInstalled: _alreadyInstalled,
            onDismiss: _dismiss,
          ),
      ],
    );
  }
}
