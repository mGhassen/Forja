import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/packs/install/plugin_pack_update_dialog.dart';

import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_profile.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_scope.dart';

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

  /// Focus before Settings / overlay — restored after Update or Cancel.
  FocusNode? _returnFocus;

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
      // Snapshot before openSettings / ExcludeFocus so Cancel lands back here.
      _returnFocus = FocusManager.instance.primaryFocus;
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
    final back = _returnFocus;
    _returnFocus = null;
    setState(() => _updates = null);
    if (!_tvFocusActive()) return;
    _scheduleRestoreFocus(back);
  }

  bool _tvFocusActive() {
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    return policy?.useFocusableMoodChips ??
        resolveShellProfile(context) == ShellProfile.tv;
  }

  void _scheduleRestoreFocus(FocusNode? back) {
    var attempts = 0;
    void attempt() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (back != null && back.canRequestFocus) {
          back.requestFocus();
          if (back.hasFocus) return;
        }
        if (ShellTvFocusCoordinator.focusFirstNavTab()) return;
        attempts += 1;
        if (attempts < 6) attempt();
      });
    }

    attempt();
  }

  @override
  Widget build(BuildContext context) {
    final updates = _updates;
    final open = updates != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shell under the confirm must not keep / reclaim D-pad focus.
        IgnorePointer(
          ignoring: open,
          child: ExcludeFocus(
            excluding: open,
            child: widget.child,
          ),
        ),
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
