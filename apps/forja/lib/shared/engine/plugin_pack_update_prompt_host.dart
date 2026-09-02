import 'package:flutter/material.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_pack_update_dialog.dart';

/// Listens for [PluginInstallCoordinator.pendingUpdatePrompt] and shows confirm.
class PluginPackUpdatePromptHost extends StatefulWidget {
  const PluginPackUpdatePromptHost({super.key, required this.child});

  final Widget child;

  @override
  State<PluginPackUpdatePromptHost> createState() =>
      _PluginPackUpdatePromptHostState();
}

class _PluginPackUpdatePromptHostState extends State<PluginPackUpdatePromptHost> {
  List<EnginePackUpdateInfo>? _updates;

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

  void _maybeShow() {
    if (!mounted || _updates != null) return;
    final next =
        PluginInstallCoordinator.instance.takePendingUpdatePrompt();
    if (next == null || next.isEmpty) return;
    setState(() => _updates = next);
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
          PluginPackUpdateOverlay(
            updates: updates,
            onDismiss: _dismiss,
          ),
      ],
    );
  }
}
