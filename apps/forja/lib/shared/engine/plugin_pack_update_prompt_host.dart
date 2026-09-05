import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_pack_update_dialog.dart';
import 'package:forja/shell/shell_bus.dart';

/// Listens for [PluginInstallCoordinator.pendingUpdatePrompt] and shows confirm.
///
/// Mirrors [PluginInstallPromptHost]: land on Settings → Forja Packs first, then
/// mount the overlay only after the pointer/frame that triggered the toast
/// action has finished (desktop mouse_tracker assert otherwise).
class PluginPackUpdatePromptHost extends StatefulWidget {
  const PluginPackUpdatePromptHost({super.key, required this.child});

  final Widget child;

  @override
  State<PluginPackUpdatePromptHost> createState() =>
      _PluginPackUpdatePromptHostState();
}

class _PluginPackUpdatePromptHostState extends State<PluginPackUpdatePromptHost> {
  List<EnginePackUpdateInfo>? _updates;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PluginInstallCoordinator.instance.pendingUpdatePrompt
        .addListener(_onPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    PluginInstallCoordinator.instance.pendingUpdatePrompt
        .removeListener(_onPending);
    super.dispose();
  }

  void _onPending() {
    if (PluginInstallCoordinator.instance.pendingUpdatePrompt.value == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted || _busy || _updates != null) return;
    final next =
        PluginInstallCoordinator.instance.takePendingUpdatePrompt();
    if (next == null || next.isEmpty) return;

    _busy = true;
    try {
      ShellBus.openSettings(
        categoryId: SettingsCategoryId.forjaPacks,
        enterDetail: true,
      );
      // Toast Update / InkWell pointer-up still owns mouse_tracker — wait it out
      // plus settings tab paint before inserting dialog MouseRegions.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _updates != null) return;
      setState(() => _updates = next);
    } finally {
      if (mounted) _busy = false;
    }
  }

  void _dismiss() {
    if (_updates == null) return;
    setState(() => _updates = null);
  }

  @override
  Widget build(BuildContext context) {
    final updates = _updates;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (updates != null)
          Positioned.fill(
            child: PluginPackUpdateOverlay(
              updates: updates,
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }
}
